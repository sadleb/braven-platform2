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