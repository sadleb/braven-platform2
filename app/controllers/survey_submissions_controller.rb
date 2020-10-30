require 'nokogiri'

class SurveySubmissionsController < ApplicationController
  include LtiHelper
  include DryCrud::Controllers::Nestable
  
  layout 'projects'

  nested_resource_of BaseCourseCustomContentVersion

  before_action :set_course_survey_version, only: [:new, :create]

  def show
    authorize @survey_submission
  end

  def new
    @survey_submission = SurveySubmission.new(
      user: current_user,
      base_course_custom_content_version: @course_survey_version,
    )
    authorize @survey_submission
  end

  def create
    @survey_submission = SurveySubmission.new(
      user: current_user,
      base_course_custom_content_version: @course_survey_version,
    )
    authorize @survey_submission

    @survey_submission.save_answers!(params.permit(survey_answer_params).to_h)

    # TODO: https://app.asana.com/0/1174274412967132/1198971448730205
    # Update Canvas assignment with line item/submission

    redirect_to @survey_submission
  end

  private
  def set_course_survey_version
    params.require(:base_course_custom_content_version_id)
    @course_survey_version = BaseCourseCustomContentVersion.find(params[:base_course_custom_content_version_id])
  end

  # Get the "name" attributes from all the <input> elements in this survey 
  # version. These are the parameters we permit from the form being submitted.
  def survey_answer_params
    doc = Nokogiri::HTML.parse(@survey_submission.survey_version.body)
    doc.xpath("//input").map{ |input| input[:name] }
  end
end
