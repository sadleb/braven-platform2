# frozen_string_literal: true

# "Publishable" behavior for controllers like PeerReviewsController and
# and WaiversController.
# 
# This concern handles creating (#publish) and deleting (#unpublish) content 
# like waivers, peer reviews, LC reviews as a Canvas assignment to a course.
# 
# When using this concern, you must add the following methods on the controller:
#
# Usage:
# class MyController
#   include Publishable
#
#   def course
#     <the_course>
#   end
#
#   def assignment_name
#     'My Assignment Name'
#   end
#
#   def lti_launch_url
#     <my_lti_launch_url> (typically `new_<...>_submission_url`)
#   end

require 'canvas_api'

module Publishable
  extend ActiveSupport::Concern

  def publish
    # We can't use `model_class` here because we don't have a PeerReview model
    authorize controller_path.classify.to_sym

    assignment = CanvasAPI.client.create_lti_assignment(
      course.canvas_course_id,
      assignment_name,
      lti_launch_url,
    )

    instance_variable.update!(
      canvas_assignment_id: assignment['id'],
    ) if model_class && instance_variable.respond_to?(:canvas_assignment_id)

    respond_to do |format|
      format.html { redirect_to(
        edit_course_path(course),
        notice: message % { subject: assignment_name, verb: 'published to' }
      ) }
      format.json { head :no_content }
    end
  end

  def unpublish
    # We can't use `model_class` here because we don't have a PeerReview model
    authorize controller_path.classify.to_sym

    CanvasAPI.client.delete_assignment(
      course.canvas_course_id,
      params[:canvas_assignment_id],
    )

    respond_to do |format|
      format.html { redirect_to(
        edit_course_path(course),
        notice: message % { subject: assignment_name, verb: 'deleted from' }
      ) }
      format.json { head :no_content }
    end
  end

private
  def message
    "%{subject} successfully %{verb} Canvas."
  end

  def method_missing(name, *args, &block)
    raise NoMethodError, method_missing_error_msg(name) if name == :course
    raise NoMethodError, method_missing_error_msg(name) if name == :assignment_name
    raise NoMethodError, method_missing_error_msg(name) if name == :lti_launch_url
    super
  end

  def method_missing_error_msg(name)
    "Publishable module expects method `#{name}` to be defined for #{self.class}. It's missing."
  end
end
