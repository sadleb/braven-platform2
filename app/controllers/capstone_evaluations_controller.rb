# frozen_string_literal: true

class CapstoneEvaluationsController < ApplicationController
  include DryCrud::Controllers::Nestable

  # Adds the #publish and #unpublish actions
  include Publishable

  layout 'admin'

  nested_resource_of Course

  COMPLETE_CAPSTONE_EVALS_ASSIGNMENT_NAME = 'TODO: Complete Capstone Evaluations'

  def assignment_name
    COMPLETE_CAPSTONE_EVALS_ASSIGNMENT_NAME
  end

  def lti_launch_url
    new_course_capstone_evaluation_submission_url(@course, protocol: 'https')
  end

end
