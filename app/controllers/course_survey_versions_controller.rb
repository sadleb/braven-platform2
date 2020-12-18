# frozen_string_literal: true

class CourseSurveyVersionsController < ApplicationController
  include DryCrud::Controllers::Nestable
  nested_resource_of Course

  # Adds the #publish, #publish_latest, #unpublish actions
  include Publishable

  prepend_before_action :set_model_instance, only: [:publish_latest, :unpublish]

  layout 'admin'

  def new
    authorize CourseSurveyVersion
    @custom_contents = Survey.all - @course.surveys
    @course_custom_content = CourseSurveyVersion.new(course: @course)
  end

private
  # For Publishable
  def assignment_name
    @course_survey_version.survey_version.title
  end

  def lti_launch_url
    @course_survey_version.new_submission_url
  end

  def versionable_instance
    params[:custom_content_id] ?
      Survey.find(params[:custom_content_id]) : # publish
      @course_survey_version.survey_version.survey # publish_latest
  end

  def version_name
    'survey_version'
  end
end
