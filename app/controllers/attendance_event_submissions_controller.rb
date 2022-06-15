# frozen_string_literal: true

require 'csv'
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
  class CSVHeaders
    FIRST_NAME = "First name"
    LAST_NAME = "Last name"
    IN_ATTENDANCE = "Present?"
    LATE = "Late?"
    ABSENCE_REASON = "Reason for absence"
    COHORT_SCHEDULE = "Cohort Schedule"
    COHORT = "Cohort"
    PLATFORM_USER_ID = "Platform User Id"

    ALL_HEADERS = [
      FIRST_NAME,
      LAST_NAME,
      IN_ATTENDANCE,
      LATE,
      ABSENCE_REASON,
      COHORT_SCHEDULE,
      COHORT,
      PLATFORM_USER_ID,
    ]
  end

  UNPROCESSED_REASON = 'unprocessed_reason'

  include DryCrud::Controllers
  include LtiHelper

  before_action :set_lti_launch, only: [:launch, :edit, :update, :bulk_export_csv, :bulk_import_new, :bulk_import_preview]
  before_action :set_accelerator_course, only: [:launch, :edit, :update, :bulk_export_csv, :bulk_import_new, :bulk_import_preview]
  # Note @attendance_event_submission is also set by DryCrud for the other actions.
  before_action :set_attendance_event_submission, only: [:bulk_export_csv, :bulk_import_new, :bulk_import_preview]
  before_action :set_all_attendance_sections, only: [:launch, :edit, :update, :bulk_export_csv, :bulk_import_preview]
  before_action :set_course_attendance_event, only: [:launch, :edit, :bulk_export_csv, :bulk_import_new, :bulk_import_preview]
  before_action :set_fellow_users, only: [:edit, :update, :bulk_export_csv, :bulk_import_preview]
  before_action :set_all_fellow_users, only: [:update, :bulk_export_csv, :bulk_import_preview]
  before_action :set_answers, only: [:edit, :bulk_export_csv]
  # TODO: evaluate removing this now that we don't use iframes.
  # https://app.asana.com/0/1174274412967132/1200999775167872/f
  skip_before_action :verify_authenticity_token, only: [:update], if: :is_sessionless_lti_launch?

  layout 'lti_canvas'

  # Note: This is a non-standard action. It is used by the "Take Attendance"
  # links in the LC Playbook course.
  def launch
    if @course_attendance_event.nil?
      authorize @accelerator_course, policy_class: AttendanceEventSubmissionPolicy
      msg = "User #{current_user} is trying to take attendance but there are no events " \
        "in the Accelerator course '#{@accelerator_course.inspect}'"
      Honeycomb.add_alert('attendance.no_events', msg)
      logger.warn(msg)
      render :no_course_attendance_events and return
    end

    if sections_as_ta.count != 1 and not current_user.admin?
      authorize @accelerator_course, policy_class: AttendanceEventSubmissionPolicy
      msg = "User #{current_user} is a TA in multiple sections. Cannot take attendance."
      Honeycomb.add_alert('attendance.multiple_sections', msg)
      logger.error(msg)
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

  #
  # Bulk Import/Export
  #

  def bulk_export_csv
    authorize @attendance_event_submission, :show?

    course = @course_attendance_event.course
    export_data = CSV.generate(headers: true) do |csv|
      csv << CSVHeaders::ALL_HEADERS

      @all_fellow_users.each do |user|
        answer = @answers.find_by(for_user: user)

        # Make sure these match the order defined in the CSV headers!
        csv << [
          user.first_name,
          user.last_name,
          answer&.in_attendance,
          answer&.late,
          answer&.absence_reason,
          user.cohort_schedule(course)&.name,
          user.cohort(course)&.name,
          user.id,
        ]
      end
    end

    respond_to do |format|
      format.csv { send_data export_data }
    end
  end

  def bulk_import_new
    authorize @attendance_event_submission, :new?
  end

  # This is a POST route.
  def bulk_import_preview
    authorize @attendance_event_submission, :new?

    validation_converter = ->(field, field_info) {
      # TODO: any validation? otherwise move this inline.

      field&.strip
    }
    data = CSV.read(params[:attendance_csv].path, 
                   headers: true,
                   # Normalize headers, to allow for variations in the source CSV.
                   header_converters: lambda { |h| h.parameterize.underscore },
                   encoding: 'bom|utf-8',
                   converters: validation_converter)
      .map(&:to_h)

    # This is a find_or_new_by() so we have an object to authorize against
    @attendance_event_submission = AttendanceEventSubmission.where(
      user: current_user,
      course_attendance_event: @course_attendance_event,
    ).order(:updated_at).last
    # TODO:
    raise if @attendance_event_submission.nil?

    # Filter
    @unprocessed_rows = []
    @unsaved_answers = []
    data.each do |row|
      # Add to unprocessed if "Present?" is empty or if the user is not in @fellow_users.
      user_id = row[CSVHeaders::PLATFORM_USER_ID.parameterize.underscore]&.to_i
      in_attendance = row[CSVHeaders::IN_ATTENDANCE.parameterize.underscore]
      if in_attendance.blank?
        row[UNPROCESSED_REASON] = "No attendance recorded in the '#{CSVHeaders::IN_ATTENDANCE}' column"
        @unprocessed_rows << row
        next
      elsif User.where(id: user_id).none?
        # Complain about invalid user IDs.
        row[UNPROCESSED_REASON] = "User ID '#{user_id}' not found"
        @unprocessed_rows << row
        next
      elsif @all_fellow_users.none? { |u| u.id == user_id }
        # Complain about non-enrolled Fellows.
        row[UNPROCESSED_REASON] = "Not currently enrolled in this course"
        @unprocessed_rows << row
        next
      end

      @unsaved_answers << AttendanceEventSubmissionAnswer.new(
        attendance_event_submission: @attendance_event_submission,
        for_user_id: row[CSVHeaders::PLATFORM_USER_ID.parameterize.underscore].to_i,
        in_attendance: to_boolean(row[CSVHeaders::IN_ATTENDANCE.parameterize.underscore]),
        late: to_boolean(row[CSVHeaders::LATE.parameterize.underscore]),
        absence_reason: row[CSVHeaders::ABSENCE_REASON.parameterize.underscore].strip,
      )
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

  # For #bulk_*
  def set_attendance_event_submission
    @attendance_event_submission = AttendanceEventSubmission.find(params[:attendance_event_submission_id])
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
    else
      # Retain functionality for normal attendance, and put the one section
      # in a Relation.
      @all_attendance_sections = Section.where(id: section&.id)
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

  # For #bulk_export_csv
  def set_all_fellow_users
    # Note this is implicitly limited to students in this course and further
    # restricted so only people with special permission can see students in
    # sections they're not the TA for, by the `set_all_attendance_sections`
    # method. If you refactor this, be sure to keep those limitations.
    ids = []
    @all_attendance_sections.each do |section|
      ids += section.students.pluck(:id)
    end
    @all_fellow_users = User.where(id: ids).order(:last_name)
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

  # Answers used for form prefill/CSV export.
  def set_answers
    answer_ids = @fellow_users.map do |fellow|
      @course_attendance_event.attendance_event_submission_answers.where(for_user_id: fellow.id)
        .order(:updated_at)
        .pluck(:id)
        .last
    end

    @answers = AttendanceEventSubmissionAnswer.where(id: answer_ids)
  end

  # For #update
  def attendance_status_by_user_hash
    attendance_event_submission_param = params.require(:attendance_event_submission)
    attendance_event_submission_param.permit!.to_h.filter do |user_id|
      # Restrict to only users in the section(s) that we have already determined
      # current_user is allowed to access.
      @all_fellow_users.any? { |user| user.id.to_s == user_id.to_s }
    end
  end

  # Custom string handling for CSV import values.
  # Returns true, false, or nil depending on the value.
  def to_boolean(value)
    value = value&.downcase&.strip
    return false if value == "no"
    ActiveModel::Type::Boolean.new.cast(value)
  end
end
