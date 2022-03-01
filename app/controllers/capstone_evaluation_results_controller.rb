# frozen_string_literal: true

class CapstoneEvaluationResultsController < ApplicationController
  include DryCrud::Controllers::Nestable
  include LtiHelper

  layout 'lti_canvas'

  nested_resource_of User

  attr_reader :lti_launch

  before_action :set_lti_launch, only: [:launch, :score]
  before_action :set_course, only: [:launch, :score]
  before_action :set_grade_capstone_eval_service_instance, only: [:launch, :score]

  # WARNING: Do not use LTI Advantage API to create or edit Capstone Evaluation Results
  # submissions for the Capstone Evaluations Teamwork grade. The #score method in this
  # controller calls the #run method in the grade_capstone_evaluations service. When this
  # service runs, it creates a submission for each user that is being given a grade so that
  # they will be able to see their Capstone Evaluation Teamwork grade breakdown from the grades
  # tab. The submissions are being graded using the CanvasAPI `create_lti_submission` method.
  # This method should only be used in the event that fellows do not ever need to
  # create a submission for an assignment. If this method is used, LTI Advantage API cannot
  # be used to submit the assignment again. Once this method is used to create a submission,
  # future submissions will only be able to be made using this method again, so fellows will
  # never be able to create a submission themselves.

  def launch
    authorize @course, policy_class: CapstoneEvaluationSubmissionPolicy
  end

  def score
    authorize :CapstoneEvaluationSubmission

    new_capstone_eval_submissions = @course.capstone_evaluation_submissions.ungraded

    if new_capstone_eval_submissions.empty?
      redirect_to launch_capstone_evaluation_results_path(lti_launch_id: @lti_launch.id), alert: 'No new submissions to grade.' and return
    end

    @grade_capstone_eval_service.run
    redirect_to launch_capstone_evaluation_results_path(lti_launch_id: @lti_launch.id), notice: 'Grades have been successfully published.'
  end

private
  def set_course
    @course = Course.find_by!(canvas_course_id: @lti_launch.course_id)
  end

  def set_grade_capstone_eval_service_instance
    @grade_capstone_eval_service = GradeCapstoneEvaluations.new(
      @course,
      @lti_launch
    )
  end
end