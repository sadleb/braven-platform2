# frozen_string_literal: true
require 'canvas_api'

# Responsible for initializing a new Canvas course:
# 1. Creates an enrollment term for the Program
# 2. creates the initial Canvas and local sections for Cohort Schedules and Teaching Assistants
# 3. creates local projects, modules, etc for those found in the Canvas course
class InitializeNewCourse
  include Rails.application.routes.url_helpers

  InitializeNewCourseError = Class.new(StandardError)

  def initialize(new_course, salesforce_program)
    @new_course = new_course
    @salesforce_program = salesforce_program
  end

  def run
    Honeycomb.start_span(name: 'initialize_new_course.run') do
      canvas_section_ids = create_sections()
      canvas_assignment_ids = initialize_assignments()
    end
  end

private

  # Grab the list of assignments from the new launched course. Look through them and for LTI assignments,
  # parse out the existing LTI launch URL, look up the resource (e.g. Project/Module/Survey/etc) that is
  # being launched and associate it with the new course as well. Then update the Canvas
  # assignment's launch URL to launch the newly associated resource.
  def initialize_assignments
    canvas_assignment_info = FetchCanvasAssignmentsInfo.new(@new_course.canvas_course_id).run

    # Projects and impact surveys
    canvas_assignment_info.course_custom_content_versions_mapping.each do |canvas_assignment_id, cccv|
      initialize_new_course_custom_content_version(canvas_assignment_id, cccv)
    end

    canvas_assignment_info.rise360_module_versions_mapping.each do |canvas_assignment_id, rise360_module_version|
      initialize_new_course_rise360_module_version(canvas_assignment_id, rise360_module_version)
    end

    # Attendance events don't need their LTI launch URLs updated, but do need
    # new CourseAttendanceEvent records in our DB.
    canvas_assignment_info.course_attendance_events_mapping.each do |canvas_assignment_id, course_attendance_event|
      initialize_new_course_attendance_event(canvas_assignment_id, course_attendance_event)
    end

    # Capstone Evaluation
    if canvas_assignment_info.canvas_capstone_evaluations_assignment_id
      initialize_new_capstone_evaluation(canvas_assignment_info.canvas_capstone_evaluations_assignment_id)
    end

    # Forms, Modules, Pre-, and Post-Accelerator assignments don't need their
    # LTI launch URLs updated for a new course because they use course-agnostic
    # endpoints.

    # TODO: Adjusting the LTI launch URLs above goes away once we switch to
    # using static endpoints for the Canvas assignments.
    # https://app.asana.com/0/1174274412967132/1199352155608256

    canvas_assignment_info.canvas_assignment_ids
  end

  # When the assignment is loaded in Canvas and does an LTI Launch, it launches a
  # CourseCustomContentVersion's submission URL. This initializes that both locally
  # and in Canvas by creating a new one associating this new Course to the same custom_content_version
  # as the old one and publishing the new URL to the new canvas_assignment_id
  def initialize_new_course_custom_content_version(canvas_assignment_id, old_course_custom_content_version)
    new_launch_url = create_new_course_custom_content_version!(canvas_assignment_id, old_course_custom_content_version)
    Rails.logger.debug("Updating Canvas Assignment[#{canvas_assignment_id}] - changing LTI launch URL to: #{new_launch_url}")
    CanvasAPI.client.update_assignment_lti_launch_url(@new_course.canvas_course_id, canvas_assignment_id, new_launch_url)
  end

  def create_new_course_custom_content_version!(canvas_assignment_id, old_course_custom_content_version)
    if old_course_custom_content_version.course.canvas_course_id == @new_course.canvas_course_id
      raise InitializeNewCourseError, "Canvas Assignment[#{canvas_assignment_id}] is already associated with #{@new_course}"
    end

    new_cccv = old_course_custom_content_version.class.create!(
      course: @new_course,
      custom_content_version: old_course_custom_content_version.custom_content_version,
      canvas_assignment_id: canvas_assignment_id,
    )

    new_launch_url = new_cccv.new_submission_url
  end

  def initialize_new_course_rise360_module_version(canvas_assignment_id, rise360_module_version)
    create_new_course_rise360_module_version!(canvas_assignment_id, rise360_module_version)
  end

  def create_new_course_rise360_module_version!(canvas_assignment_id, rise360_module_version)
    CourseRise360ModuleVersion.create!(
      course: @new_course,
      rise360_module_version: rise360_module_version,
      canvas_assignment_id: canvas_assignment_id,
    )
  end

  def initialize_new_course_attendance_event(canvas_assignment_id, old_course_attendance_event)
    create_new_course_attendance_event!(canvas_assignment_id, old_course_attendance_event)
  end

  def create_new_course_attendance_event!(canvas_assignment_id, old_course_attendance_event)
    if old_course_attendance_event.course.canvas_course_id == @new_course.canvas_course_id
      raise InitializeNewCourseError, "Canvas Assignment[#{canvas_assignment_id}] is already associated with #{@new_course}"
    end

    new_course_attendance_event = CourseAttendanceEvent.create!(
      course: @new_course,
      attendance_event: old_course_attendance_event.attendance_event,
      canvas_assignment_id: canvas_assignment_id,
    )
  end

  def initialize_new_capstone_evaluation(canvas_assignment_id)
    CanvasAPI.client.update_assignment_lti_launch_url(
      @new_course.canvas_course_id,
      canvas_assignment_id,
      new_course_capstone_evaluation_submission_url(@new_course, protocol: 'https'),
    )
  end

  # On Program launch, create the Cohort Schedule sections (for both the Accelerator course
  # and LC Playbook source, with SIS IDs). We don't create these on the fly as part of
  # sync b/c the due dates need to be manually set on them and the sections should not be deleted
  # b/c we'd lose the dates.
  #
  # Also create the Teaching Assistants section on launch since it needs to be there
  # and there is only ever one per course.
  def create_sections
    canvas_section_ids = []

    @salesforce_program.cohort_schedules.each do |cohort_schedule|
      local_section = CreateSection.new(
        @new_course,
        cohort_schedule.canvas_section_name,
        Section::Type::COHORT_SCHEDULE,
        cohort_schedule.sfid
      ).run

      canvas_section_ids << local_section.canvas_section_id
    end

    local_ta_section = CreateSection.new(
      @new_course,
      SectionConstants::TA_SECTION,
      Section::Type::TEACHING_ASSISTANTS
    ).run
    canvas_section_ids << local_ta_section.canvas_section_id

    canvas_section_ids
  end

end
