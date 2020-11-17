require 'lti_advantage_api'
require 'lti_score'
require 'nokogiri'

class SurveySubmissionsController < ApplicationController
  include LtiHelper
  include DryCrud::Controllers::Nestable
  
  layout 'projects'

  nested_resource_of BaseCourseSurveyVersion

  before_action :set_lti_launch
  skip_before_action :verify_authenticity_token, only: [:create], if: :is_sessionless_lti_launch?

  def show
    authorize @survey_submission
  end

  def new
    @survey_submission = SurveySubmission.new(
      user: current_user,
      base_course_survey_version: @base_course_survey_version,
    )
    authorize @survey_submission

    # Only one submission per user and impact survey
    previous_submission = SurveySubmission.where(
      base_course_survey_version: @base_course_survey_version,
      user: current_user,
    ).first
    redirect_to previous_submission if previous_submission
  end

  def create
    @survey_submission = SurveySubmission.new(
      user: current_user,
      base_course_survey_version: @base_course_survey_version,
    )
    authorize @survey_submission

    # Record in our DB first, so we have the data even if updating Canvas fails
    @survey_submission.save_answers!(params.permit(survey_answer_params).to_h)

    # Update Canvas
    lti_score = LtiScore.new_survey_submission(
      @current_user.canvas_user_id,
      survey_submission_url(@survey_submission, protocol: 'https'),
    )
    LtiAdvantageAPI.new(@lti_launch).create_score(lti_score)

    redirect_to @survey_submission
  end

private
  # Get the "name" attributes from all the <input> elements in this survey 
  # version. These are the parameters we permit from the form being submitted.
  def survey_answer_params
    doc = Nokogiri::HTML.parse(@survey_submission.survey_version.body)
    doc.xpath("//input|//select|//textarea").map{ |input| input[:name] }
  end
end
