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
  before_action :set_accelerator_course, only: [:launch, :edit, :update]
  before_action :set_all_attendance_sections, only: [:launch, :edit, :update]
  before_action :set_course_attendance_event, only: [:launch, :edit]
  before_action :set_fellow_users, only: [:edit, :update]
  # TODO: evaluate removing this now that we don't use iframes.
  # https://app.asana.com/0/1174274412967132/1200999775167872/f
  skip_before_action :verify_authenticity_token, only: [:update], if: :is_sessionless_lti_launch?

  layout 'lti_canvas'

  # Note: This is a non-standard action. It is used by the "Take Attendance"
  # links in the LC Playbook course.
  def launch
    if @course_attendance_event.nil?
      authorize @accelerator_course, policy_class: AttendanceEventSubmissionPolicy
      Honeycomb.add_field('alert.attendance.no_events', true)
      logger.warn("User #{current_user} is trying to take attendance but there are no events " \
                  "in the Accelerator course '#{@accelerator_course.inspect}'")
      render :no_course_attendance_events and return
    end

    if sections_as_ta.count != 1 and not current_user.admin?
      authorize @accelerator_course, policy_class: AttendanceEventSubmissionPolicy
      Honeycomb.add_field('alert.attendance.multiple_sections', true)
      logger.error("User #{current_user} is a TA in multiple sections. Cannot take attendance.")
      render :multiple_sections and return
    end

    # This is a find_or_new_by() so we have an object to authorize against
    @attendance_event_submission = AttendanceEventSubmission.where(
      user: current_user,
      course_attendance_event: @course_attendance_event,
    ).order(:updated_at).last || AttendanceEventSubmission.new(
      user: current_user,
      course_attendance_event: @course_attendance_event,
    )
    authorize @attendance_event_submission
    @attendance_event_submission.save! # Do this after the authorization so we don't add an unauthorized .new record
    redirect_to edit_attendance_event_submission_path(
      @attendance_event_submission,
      course_attendance_event_id: @course_attendance_event,
      section_id: section.id,
      lti_launch_id: @lti_launch.id,
    )
  end

  def edit
    authorize @attendance_event_submission
    @course_attendance_events = @attendance_event_submission.course.course_attendance_events.order_by_title
    @section = section

    answer_ids = @fellow_users.map do |fellow|
      @course_attendance_event.attendance_event_submission_answers.where(for_user_id: fellow.id)
        .order(:updated_at)
        .pluck(:id)
        .last
    end

    @answers = AttendanceEventSubmissionAnswer.where(id: answer_ids)
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
          lti_launch_id: @lti_launch.id,
        ),
        notice: "Attendance for #{title} saved."
      ) }
      format.json { head :no_content }
    end
  end

private
  # For #launch, #edit, #update
  def set_accelerator_course
    return if @accelerator_course

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

  # For #launch, #edit
  def set_course_attendance_event
    if params[:course_attendance_event_id]
      @course_attendance_event = @accelerator_course.course_attendance_events.find(
        params[:course_attendance_event_id],
      )
    else
      @course_attendance_event = helpers.get_default_course_attendance_event(section)
    end
  end

  def set_all_attendance_sections
    if current_user.can_take_attendance_for_all?
      @all_attendance_sections = Section.cohort_or_cohort_schedule.with_users
        .where(course: @accelerator_course).order_by_name
    end
  end

  # For #edit, #update
  def set_fellow_users
    # Get all users enrolled as students in the section.
    # Note this is implicitly limited to students in this course and further
    # restricted so only people with special permission can see students in
    # sections they're not the TA for, by the `section` call. If you refactor
    # this, be sure to keep those limitations.
    @fellow_users = []
    @fellow_users = section.students.order(:last_name) if section
  end

  def section
    # If we have special permission, try to use the section_id param.
    # Fall back to first section as TA, then first section in the course (if not a TA).
    if current_user.can_take_attendance_for_all?
      return @accelerator_course.sections.find_by_id(params[:section_id]) || sections_as_ta.first || @all_attendance_sections.first
    end

    # If no special permission, fall back to TA section.
    # At the moment we only expect a Leadership Coach to be in one section
    # and show an error page if that's not true.
    sections_as_ta.first
  end

  # Get all Accelerator course sections where this user is a TA.
  def sections_as_ta
    @sections_as_ta ||= current_user.ta_sections.where(course: @accelerator_course)
  end

  # For #update
  def attendance_status_by_user_hash
    attendance_event_submission_param = params.require(:attendance_event_submission)
    attendance_event_submission_param.permit!.to_h.filter do |user_id|
      # Restrict to only users in the section, which we have already determined
      # current_user is allowed to access.
      @fellow_users.any? { |user| user.id.to_s == user_id.to_s }
    end
  end
end
