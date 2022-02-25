# frozen_string_literal: true

class CapstoneEvaluationsController < ApplicationController
  include DryCrud::Controllers::Nestable

  # Adds the #publish and #unpublish actions
  include Publishable

  layout 'admin'

  nested_resource_of Course

  COMPLETE_CAPSTONE_EVALS_ASSIGNMENT_NAME = 'TODO: Complete Capstone Evaluations'
  CAPSTONE_EVALS_RESULTS_ASSIGNMENT_NAME = 'GROUP PROJECT: Capstone Challenge: Teamwork'

  # Extend Publishable.publish with support for the capstone eval results
  # assignment, where team score results are submitted as a grade.
  def publish
    authorize :CapstoneEvaluation

    # Add the results assignment.
    assignment = CanvasAPI.client.create_lti_assignment(
      @course.canvas_course_id,
      CAPSTONE_EVALS_RESULTS_ASSIGNMENT_NAME,
      nil,
      CapstoneEvaluationQuestion::TOTAL_POINTS_POSSIBLE
    )

    CanvasAPI.client.update_assignment_lti_launch_url(
      @course.canvas_course_id,
      assignment['id'],
      launch_capstone_evaluation_results_url(protocol: 'https')
    )

    # Let Publishable do its stuff.
    super
  end

  # Not actions.
  def assignment_name
    COMPLETE_CAPSTONE_EVALS_ASSIGNMENT_NAME
  end

  def lti_launch_url
    new_course_capstone_evaluation_submission_url(@course, protocol: 'https')
  end

end
