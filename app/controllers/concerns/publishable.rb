# frozen_string_literal: true

# "Publishable" behavior for controllers that modify Assignments in a Canvas
# course, for example:
#   - CapstoneEvaluationsController
#   - FormsController
#   - Course{Project, Survey, Rise360Module}VersionsControllers
#
# This concern adds 3 actions to your controller to modify Canvas:
#   - #publish: creates a new Assignment in Canvas
#   - #publish_latest: updates the existing Canvas assignment
#   - #unpublish: deletes the Canvas assignment
#
# The above actions automatically execute a *_model_instance callback to
# manipulate the model associated with the controller if model_class exists.
#
# You can choose which of these actions your controller exposes by configuring
# them in config/routes.rb.
#
# For example, {CapstoneEvaluations,FormsControllers} do not currently support
# #publish_latest. However, the Course*VersionsControllers do.
#
# This concern heavily depends on DryCrud::Controllers::Nestable, and requires
# the including controller to be nested under the parent Course.
#
# Usage:
#
#   include DryCrud::Controllers::Nestable
#   nested_resource_of Course
#   include Publishable
#
# You will also need to define the following in your controller:
#
#   # Used by #publish and #publish_latest to set the Canvas assignment's name
#   def assignment_name
#     'My Assignment Name'
#   end
#
#   # Used by #publish to set the URL the Canvas assigment redirects to
#   def lti_launch_url
#     <my_lti_launch_url> (typically `new_<...>_submission_url`)
#   end
#
#   # Used by #publish_latest to get the instance to call create_version! on
#   def versionable_instance
#     (typically coursemodelversion.version.model)
#   end
#
#   # Used by publish_latest determine the parameter to pass to update!() with
#   # the new version
#   def version_name
#     (typically model_version)
#   end
#
# If you want to associate your Model to a particular Canvas assignment, you
# will need to implement a Model with the `canvas_assignment_id` attribute.
#
# If you want to have versioning history for your content, you will need to
# have a Model that implements Versionable.

require 'canvas_api'

module Publishable
  extend ActiveSupport::Concern
  PublishableError = Class.new(StandardError)

  included do
    before_action :create_model_instance,  only: [:publish]
    before_action :update_model_instance,  only: [:publish_latest]
    after_action  :destroy_model_instance, only: [:unpublish]
  end

  def publish
    # We can't use `model_class` here because we don't have a CapstoneEvaluation model
    authorize controller_path.classify.to_sym

    assignment = CanvasAPI.client.create_lti_assignment(
      @course.canvas_course_id,
      assignment_name,
      nil,
      points_possible,
      open_in_new_tab
    )

    instance_variable.update!(
      canvas_assignment_id: assignment['id'],
    ) if model_class && instance_variable.respond_to?(:canvas_assignment_id)

    # This needs to happen as a separate update because of projects and surveys,
    # which require a canvas_assignment_id before you can save the record.
    # But you need a saved record in order to get the new_submission_url.
    # This was just the most straightforward way to break that dependency.
    CanvasAPI.client.update_assignment_lti_launch_url(
      @course.canvas_course_id,
      assignment['id'],
      lti_launch_url,
    )

    respond_to do |format|
      format.html { redirect_to(
        redirect_path,
        notice: message % { subject: assignment_name, verb: 'published to' }
      ) }
      format.json { head :no_content }
    end
  end

  def publish_latest
    unless can_publish_latest?
      raise PublishableError.new 'Failed to publish_latest because there is student data associated with this model'
    end

    # Update the Canvas assignment name and LTI launch URL
    # This doubles as a check that the assignment exists in Canvas, so we don't
    # fail silently (e.g., we think we're updating an assignment, but nothing
    # changes in Canvas).
    CanvasAPI.client.update_assignment_name(
      @course.canvas_course_id,
      canvas_assignment_id,
      assignment_name,
    )
    CanvasAPI.client.update_assignment_lti_launch_url(
      @course.canvas_course_id,
      canvas_assignment_id,
      lti_launch_url,
    )

    respond_to do |format|
      format.html { redirect_to(
        redirect_path,
        notice: message % { subject: assignment_name, verb: 'updated in' }
      ) }
      format.json { head :no_content }
    end
  end

  def unpublish
    # We can't use `model_class` here because we don't have a CapstoneEvaluation model
    authorize controller_path.classify.to_sym

    unless can_unpublish?
      raise PublishableError.new 'Failed to unpublish because there is student data associated with this model'
    end

    Honeycomb.add_field('canvas.course.id', @course.canvas_course_id.to_s)
    Honeycomb.add_field('canvas.assignment.id', canvas_assignment_id.to_s)

    begin
      CanvasAPI.client.delete_assignment(
        @course.canvas_course_id,
        canvas_assignment_id,
      )
    rescue RestClient::NotFound
      # This gets thrown when the assignment doesn't exist in Canvas.
      # It's fine to delete the record from our DB in this case.
      Honeycomb.add_field('unpublish.canvas_assignment_not_found', true)
    end

    respond_to do |format|
      format.html { redirect_to(
        redirect_path,
        notice: message % { subject: assignment_name, verb: 'deleted from' }
      ) }
      format.json { head :no_content }
    end
  end

private
  def create_model_instance
    return unless model_class
    authorize model_class
    instance_variable_set(
      :"@#{instance_variable_name}",
      model_class.new({
        course: @course,
        version_name => versionable_instance.create_version!(@current_user)
      })
    )
  end

  def update_model_instance
    return unless model_class
    authorize instance_variable
    if can_publish_latest?
      instance_variable.update!({
        version_name => versionable_instance.create_version!(current_user),
      })
    end
  end

  def destroy_model_instance
    return unless model_class
    authorize instance_variable
    if can_unpublish?
      instance_variable.destroy!
    end
  end

  def redirect_path
    edit_course_path(@course)
  end

  def message
    "%{subject} successfully %{verb} Canvas."
  end

  def canvas_assignment_id
    if model_class && instance_variable.respond_to?(:canvas_assignment_id)
      return instance_variable.canvas_assignment_id
    end
    params.require(:canvas_assignment_id)
  end

  # Override me in the controller to provide the points_possible that should be set on this assignment.
  # Defaults to nil which is translated to 0 in Canvas
  def points_possible
    nil
  end

  # Override me if this assignment should be loaded in an iframe. Be very careful though
  # b/c Safari and other browsers tend to not allow cookies or redirects with the full
  # Location path in the header when cross-site in an iframe. Thoroughly test across browsers
  # if you set this false.
  def open_in_new_tab
    true
  end

  # Override me in the controller if there is logic that would prevent publish_latest
  def can_publish_latest?
    true
  end

  # Override me in the controller if there is logic that would prevent unpublish
  def can_unpublish?
    true
  end

  def method_missing(name, *args, &block)
    raise NoMethodError, method_missing_error_msg(name) if name == :assignment_name
    raise NoMethodError, method_missing_error_msg(name) if name == :lti_launch_url
    super
  end

  def method_missing_error_msg(name)
    "Publishable module expects method `#{name}` to be defined for #{self.class}. It's missing."
  end
end
