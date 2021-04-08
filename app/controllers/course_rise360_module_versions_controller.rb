# frozen_string_literal: true

class CourseRise360ModuleVersionsController < ApplicationController
  include DryCrud::Controllers::Nestable
  nested_resource_of Course

  # Adds the #publish, #publish_latest, #unpublish actions
  include Publishable

  prepend_before_action :set_model_instance, only: [:publish_latest, :unpublish]
  append_before_action :destroy_interactions, only: [:unpublish]
  after_action :destroy_states, only: [:publish_latest]

  layout 'admin'

  def new
    authorize Rise360Module
    @modules = Rise360Module.all - @course.rise360_modules
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

  def destroy_states
    # Delete states for old module versions, so they don't break module loading.
    Rise360ModuleState.where(
      canvas_assignment_id: instance_variable.canvas_assignment_id,
      state_id: 'bookmark',
    ).destroy_all
  end

  def destroy_interactions
    # Delete interactions for deleted modules, so they don't break grading.
    Rise360ModuleInteraction.where(canvas_assignment_id: instance_variable.canvas_assignment_id).destroy_all
  end
end
