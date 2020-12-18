# frozen_string_literal: true

class CourseProjectVersionsController < ApplicationController
  include DryCrud::Controllers::Nestable
  nested_resource_of Course

  # Adds the #publish, #publish_latest, #unpublish actions
  include Publishable

  prepend_before_action :set_model_instance, only: [:publish_latest, :unpublish]
  before_action :set_rubrics, only: [:new]
  after_action :add_rubric, only: [:publish]

  layout 'admin'

  def new
    authorize CourseProjectVersion
    @custom_contents = Project.all - @course.projects
    @course_custom_content = CourseProjectVersion.new(course: @course)
  end

private
  def set_rubrics
    @rubrics = CanvasAPI.client.get_rubrics(
      @course.canvas_course_id,
      true, # filter_already_associated_rubrics
    )
  end

  def add_rubric
    return unless params[:rubric_id].present?
    CanvasAPI.client.add_rubric_to_assignment(
      @course.canvas_course_id,
      @course_project_version.canvas_assignment_id,
      params[:rubric_id],
    )
  end

  # For Publishable
  def assignment_name
    @course_project_version.project_version.title
  end

  def lti_launch_url
    @course_project_version.new_submission_url
  end

  def versionable_instance
    versionable =
      if params[:custom_content_id]
        Project.find(params[:custom_content_id])
      else
        @course_project_version.project_version.project
      end
  end

  def version_name
    'project_version'
  end
end
