class RateThisModuleSubmissionsController < ApplicationController
  include LtiHelper

  before_action :set_lti_launch_from_referrer, only: [:launch]
  before_action :set_lti_launch, only: [:edit, :update]
  before_action :set_course_rise360_module_version, only: [:launch]
  skip_before_action :verify_authenticity_token, only: [:update], if: :is_sessionless_lti_launch?

  layout 'lti_canvas'

  def launch
    # Note: we immediately discard this `new` submission after using it
    # to check the policy, and use find_or_create_by below instead.
    # It's just easier to always pass in a submission object to the policy.
    authorize RateThisModuleSubmission.new(
      user: current_user,
      course_rise360_module_version: @course_rise360_module_version
    )

    rate_this_module_submission = RateThisModuleSubmission.find_or_create_by(
      user: current_user,
      course_rise360_module_version: @course_rise360_module_version,
    )
    redirect_to edit_rate_this_module_submission_path(
      rate_this_module_submission,
      state: @lti_launch.state,
    )
  end

  def edit
    authorize @rate_this_module_submission
    @prefill_score = @rate_this_module_submission.answers.find_by(
      input_name: 'module_score'
    )&.input_value or ''
    @prefill_feedback = @rate_this_module_submission.answers.find_by(
      input_name: 'module_feedback'
    )&.input_value or ''
  end

  def update
    authorize @rate_this_module_submission

    @rate_this_module_submission.save_answers!(answers_params_hash)

    respond_to do |format|
      format.html { redirect_to(
        edit_rate_this_module_submission_path(
          @rate_this_module_submission,
          state: @lti_launch.state
        ),
        notice: 'Feedback submitted.'
      ) }
      format.json { head :no_content }
    end
  end

private

  # Select the module_version based on the information in the LtiLaunch payload.
  def set_course_rise360_module_version
    @course_rise360_module_version = CourseRise360ModuleVersion.find_by(
      canvas_assignment_id: @lti_launch.request_message.custom['assignment_id'],
    )
  end

  def answers_params_hash
    # Since this controller accepts arbitrary params to #create, explicitly remove
    # the params we know we don't want.
    params.require(:rate_this_module_submission).permit(:module_score, :module_feedback).to_h
  end
end
