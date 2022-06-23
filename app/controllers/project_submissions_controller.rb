require 'lti_advantage_api'
require 'lti_score'

class ProjectSubmissionsController < ApplicationController
  include LtiHelper

  include DryCrud::Controllers::Nestable

  # Note we're not using Submittable here, since the behavior for projects differs
  # significantly from other Submittables.

  nested_resource_of CourseProjectVersion

  layout 'lti_canvas'

  before_action :set_lti_launch
  # TODO: evaluate removing this now that we don't use iframes.
  # https://app.asana.com/0/1174274412967132/1200999775167872/f
  skip_before_action :verify_authenticity_token, only: [:create], if: :is_sessionless_lti_launch?

  before_action :set_has_previous_submission, only: [:edit, :new]
  before_action :set_read_only, only: [:edit]

  def show
    authorize @project_submission
  end

  # Note: this should only be called on unsubmitted submissions.
  def edit
    authorize @project_submission
    render :edit_submitted, status: 403 and return if @project_submission.is_submitted
  end

  def submit
    # Note: There should be one and only one match.
    # In other cases this will exhibit undefined behavior.
    @project_submission = ProjectSubmission.find_or_create_by!(
      user: current_user,
      course_project_version: @course_project_version,
      is_submitted: false,
    )
    authorize @project_submission, :update?

    # Mark it submitted and get things ready for them to work on a re-submission.
    # Do this before updating Canvas because if it fails there is no way I've found to
    # delete a submission from Canvas in order to keep things consistent.
    # Worse case scenario is we have orphaned submissions on the backend that are
    # not viewable in Canvas if this succeeds but updating Canvas fails.
    @project_submission.save_answers!

    # Update Canvas so that users can view the read-only submission there.
    lti_score = LtiScore.new_project_submission(
      current_user.canvas_user_id,
      course_project_version_project_submission_url(
        @course_project_version,
        @project_submission,
        protocol: 'https'
      ),
    )
    LtiAdvantageAPI.new(@lti_launch).create_score(lti_score)

    # After submitting successfully, redirect to #new to immediately create
    # another unsubmitted submission.
    # Note: This assumes Projects always allow resubmissions.
    redirect_to new_course_project_version_project_submission_path(
      @course_project_version,
      lti_launch_id: @lti_launch.id,
    )
  end

  # NOTE: This action exhibits nonstandard behavior!! It creates submission!
  # 
  # Why? A new project submission is one that is in an unsubmitted state,
  # not something that doesn't exist in the database. This just makes
  # sure we have the proper unsubmitted one to work with and redirects
  # to edit it. We made a conscious decision to do this non-standard thing
  # because we wanted to have a submission before answers started coming in
  # so that we could tie the answers to the submission.
  def new
    @project_submission = ProjectSubmission.find_or_create_by!(
      user: current_user,
      course_project_version: @course_project_version,
      is_submitted: false,
    )

    authorize @project_submission

    redirect_to edit_course_project_version_project_submission_path(
      @course_project_version,
      @project_submission,
      lti_launch_id: @lti_launch.id,
    )
  end

private

  def set_has_previous_submission
    @has_previous_submission = ProjectSubmission.where(
      course_project_version: @course_project_version,
      user: current_user,
      is_submitted: true,
    ).exists?
  end

  def set_read_only
    @read_only = false
    program = HerokuConnect::Program.find_by(canvas_cloud_accelerator_course_id__c: @lti_launch.course_id)
    if program.nil?
      msg = "No program found for Course with the canvas course id: #{@lti_launch.course_id}. " +
      "Projects will automatically be launched in edit mode instead of read only mode if a program is " +
      "missing, even if the 'Grades Finalized Date' has passed."
      Honeycomb.add_support_alert('missing_program_error', msg)
    end

    # Return and launch project like normal if the program grades_finalized_date hasn't passed
    # Using the safety operator after program in case there is a missing program
    # If a program is missing, default to opening in edit mode
    # Convert the grades finalized date to the end of the day in the time zone of the program
    return unless program&.grades_finalized_date__c&.end_of_day&.in_time_zone(program&.default_timezone__c)&.past?

    participant = HerokuConnect::Participant.find_participant(current_user.salesforce_id, program)
    # Return and launch project like normal if the participant has a grades_finalized_extension date and it hasn't passed
    # Convert the grades finalized extension to the end of the day in the time zone of the program
    return unless participant.grades_finalized_extension__c.blank? ||
                  participant.grades_finalized_extension__c&.end_of_day&.in_time_zone(program.default_timezone__c)&.past?

    # If grades_finalized_date has passed and the participant does not have an extension, make project read only
    @read_only = true
  end
end
