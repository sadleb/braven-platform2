# frozen_string_literal: true

class CourseRise360ModuleVersionsController < ApplicationController
  include DryCrud::Controllers::Nestable
  nested_resource_of Course

  # Adds the #publish, #publish_latest, #unpublish actions
  include Publishable

  prepend_before_action :force_destroy_references, only: [:publish_latest, :unpublish]
  prepend_before_action :set_model_instance, only: [:before_publish_latest, :publish_latest, :unpublish, :before_unpublish]

  layout 'admin'

  def new
    authorize Rise360Module
    @modules = Rise360Module.all - @course.rise360_modules
  end

  # Publishes the latest Rise360ModuleVersion for this Module to the Canvas assignment.
  #
  # Note that we can't safely publish latest without purging all references.
  # This is because Rise360ModuleState objects are opaque to us and can cause
  # the newly published package to hang if we use the old ones. Also b/c the content of
  # the package could have changed such that the existing grades would be incorrect.
  def publish_latest
    authorize @course_rise360_module_version
    if can_publish_latest?
      destroy_references
      super
    else
      redirect_to before_publish_latest_course_course_rise360_module_version_path and return
    end
  end

  # Shows any messages related to publish_latest that that caller may have to act on before
  # allowing it.
  def before_publish_latest
    authorize @course_rise360_module_version
  end

  # Unpublishes the Rise360ModuleVersion as a Canvas assignment.
  def unpublish
    authorize @course_rise360_module_version
    if can_unpublish?
      destroy_references
      super
    else
      redirect_to before_unpublish_course_course_rise360_module_version_path and return
    end
  end

  # Shows any messages related to unpublish that caller may have to act on before
  # allowing it.
  #
  # TODO: instead of just saying that you can't unpublish, show a list of students whose data
  # would get blown away and provide a button to unpublish anyway and purge that data.
  # https://app.asana.com/0/1174274412967132/1200410628872768
  def before_unpublish
    authorize @course_rise360_module_version
  end

private
  # For Publishable
  def assignment_name
    @course_rise360_module_version.rise360_module_version.name
  end

  # This launch URL is different from Projects and Surveys, which use
  # new_*_submission_url(). This is because Rise360Modules are not submitted.
  # The rise360_zipfile automatically emits xAPI events for user interactions
  # with the content that are recorded in Rise360ModuleInteractions, which is
  # then used to automatically grade students for participation/engagement, so
  # we just need a link to the particular version of the module to do an LTI
  # launch.
  # TODO: Convert this to use a static endpoint for LTI launch
  # https://app.asana.com/0/1174274412967132/1199352155608256
  def lti_launch_url
    rise360_module_version_url(
      @course_rise360_module_version.rise360_module_version,
      protocol: 'https',
    )
  end

  def versionable_instance
    params[:rise360_module_id] ?
      Rise360Module.find(params[:rise360_module_id]) : #publish
      @course_rise360_module_version.rise360_module_version.rise360_module # publish_latest
  end

  def version_name
    'rise360_module_version'
  end

  def can_publish_latest?
    !@course_rise360_module_version.has_student_data?
  end

  def can_unpublish?
    !@course_rise360_module_version.has_student_data?
  end

  # END: For Publishable

  # Need to do this before the Publishable before_action's run so that they work
  def force_destroy_references
    destroy_references if params[:force_delete_student_data]
  end

  # Destroys all data the references this @course_rise360_module_version so that
  # we're back into a pristine state as though it was just freshly published
  def destroy_references
    ActiveRecord::Base.transaction do
      canvas_assignment_id = @course_rise360_module_version.canvas_assignment_id

      # Delete interactions for deleted modules, so they don't break grading.
      Rise360ModuleInteraction.where(canvas_assignment_id: canvas_assignment_id).destroy_all

      # Delete states for old module versions, so they don't break module loading.
      # This completely reset's their progress in the module when they open it back
      # up. They have to start from the beginning. Note: generally, only the bookmark
      # state seems to cause the module to hang, but it's cleaner to just have a blanket
      # rule that publishing latest and unpublishing blows away everything for that module
      # assignment.
      Rise360ModuleState.where(canvas_assignment_id: canvas_assignment_id).destroy_all

      # Delete grade records (that don't actually store grades at the moment) so that we're
      # back in a fresh state as though no student has opened the module.
      @course_rise360_module_version.rise360_module_grades.destroy_all
    end
  end

end
