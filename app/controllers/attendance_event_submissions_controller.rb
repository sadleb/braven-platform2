# frozen_string_literal: true

require 'attendance_grade_calculator'
require 'canvas_api'
require 'salesforce_api'

# This controller handles the "Take Attendance" link that Leadership Coaches
# see in the LC Playbook course.
# We assume that the `current_user` is an LC and @course is the LC Playbook
# course that they are enrolled in as a student.
# We also assume the LC is enrolled in the appropriate Accelerator course
# as a TA.
#
# It is responsible for submitted a set of "answers", one per Fellow, that
# represents their attendance for an event.
class AttendanceEventSubmissionsController < ApplicationController
  include DryCrud::Controllers
  include LtiHelper

  before_action :set_lti_launch, only: [:launch, :edit, :update]
  before_action :set_accelerator_course, only: [:launch, :update]
  before_action :set_course_attendance_event, only: [:launch]  
  before_action :set_fellow_users, only: [:edit, :update]
  skip_before_action :verify_authenticity_token, only: [:update], if: :is_sessionless_lti_launch?

  layout 'lti_canvas'

  # Note: This is a non-standard action. It is used by the "Take Attendance"
  # links in the LC Playbook course.
  def launch
    if @course_attendance_event.nil?
      authorize @accelerator_course, policy_class: AttendanceEventSubmissionPolicy
      render :no_course_attendance_events and return
    end

    # This is a find_or_new_by() so we have an object to authorize against
    attendance_event_submission = AttendanceEventSubmission.find_by(
      course_attendance_event: @course_attendance_event,
    ) || AttendanceEventSubmission.new(
      course_attendance_event: @course_attendance_event,
    )
    authorize attendance_event_submission
    attendance_event_submission.update!(user: current_user)
    redirect_to edit_attendance_event_submission_path(
      attendance_event_submission,
      state: @lti_launch.state,
    )
  end

  def edit
    authorize @attendance_event_submission
    @course_attendance_events = @attendance_event_submission.course.course_attendance_events
  end

  def update
    authorize @attendance_event_submission

    # Save attendance to our DB
    @attendance_event_submission.save_answers!(
      attendance_status_by_user_hash,
      current_user,
    )

    # Update Fellow grades in Canvas
    CanvasAPI.client.update_grades(
      @accelerator_course.canvas_course_id,
      @attendance_event_submission.course_attendance_event.canvas_assignment_id,
      AttendanceGradeCalculator.compute_grades(@attendance_event_submission),
    )

    title = @attendance_event_submission.course_attendance_event.attendance_event.title
    respond_to do |format|
      format.html { redirect_to(
        edit_attendance_event_submission_path(
          @attendance_event_submission,
          state: @lti_launch.state,
        ),
        notice: "Attendance for #{title} saved."
      ) }
      format.json { head :no_content }
    end
  end

private
  # For #launch, #update
  def set_accelerator_course
    # Get this course, the LC Playbook course, from the LTI launch
    lc_playbook_course = Course.find_by(
      canvas_course_id: @lti_launch.request_message.canvas_course_id,
    )

    # Figure out the Accelerator course using Salesforce
    accelerator_canvas_course_id = SalesforceAPI.client.get_accelerator_course_id_from_lc_playbook_course_id(
      lc_playbook_course.canvas_course_id,
    )

    @accelerator_course = Course.find_by(canvas_course_id: accelerator_canvas_course_id)
  end

  # For #launch
  def set_course_attendance_event
    if params[:course_attendance_event_id]
      @course_attendance_event = @accelerator_course.course_attendance_events.find(
        params[:course_attendance_event_id],
      )
    else
      # If unspecified, use the first attendance event
      # TODO: Magically guess this based on date/time
      @course_attendance_event = @accelerator_course.course_attendance_events.first
    end
  end

  # For #edit, #update
  def set_fellow_users
    # Get all Accelerator course sections where this user is a TA
    sections_as_ta = current_user
      .sections_with_role(RoleConstants::TA_ENROLLMENT)
      .select { |section| section.course_id == @attendance_event_submission.course.id }

    # Get all users enrolled as students in each section. At the moment we only expect
    # a Leadership Coach to be in one section, so this is a graceful way to handle the situation
    # where they happen to be in multiple, just showing them all. If we encounter this in
    # the wild, revisit how to handle it.
    @fellow_users = []
    sections_as_ta.each do |section|
      @fellow_users += section.students
    end
  end

  # For #update
  def attendance_status_by_user_hash
    attendance_event_submission_param = params.require(:attendance_event_submission)
    attendance_event_submission_param.permit!.to_h.filter do |user_id|
       @fellow_users.any? { |user| user.id.to_s == user_id.to_s }
    end
  end
end
