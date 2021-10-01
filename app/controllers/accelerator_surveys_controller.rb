# frozen_string_literal: true

# We have Pre- and Post-Accelerator Surveys that Fellows respond to at the
# beginning and end of the course. These surveys are built on FormAssembly.
# This controller handles publishing and unpublishing these surveys as
# Canvas Assignments to a Canvas Course.
# For how we render and submit the surveys in the Canvas Assignment, see the
# controller for `lti_launch_url`, AcceleratorSurveySubmissionsController.
class AcceleratorSurveysController < ApplicationController
  include DryCrud::Controllers::Nestable
  nested_resource_of Course

  # Adds the #publish and #unpublish actions
  include Publishable

  layout 'admin'

  prepend_before_action :set_type!

  ACCELERATOR_SURVEY_POINTS_POSSIBLE = 5.0

private
  # For Publishable
  def assignment_name
    "TODO: Complete #{@type}-Accelerator Survey"
  end

  def points_possible
    ACCELERATOR_SURVEY_POINTS_POSSIBLE
  end

  def lti_launch_url
    send(
      "launch_#{@type.downcase}accelerator_survey_submissions_url",
      protocol: 'https',
    )
  end

  def set_type!
    params.require(:type)
    raise NotImplementedError unless ['Pre', 'Post'].include? params[:type]
    @type = params[:type]
  end
end
