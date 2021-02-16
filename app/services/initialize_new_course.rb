# frozen_string_literal: true
require 'canvas_api'

# Responsible for initializing a new Canvas course:
# 1. creates the initial Canvas Sections if specified
# 2. creates local projects, modules, etc for those found in the Canvas course
#
# Note: we discussed having the platform app be the place where all actions that required
# us to store information in our local database would go through a platform Course Management
# UI and then relying on the local database information to reconcile and populate newly launched
# courses. We still want to move in the direction of having some key actions, such as creating
# a new LTI linked Canvas assignment (e.g. a Project) be done from the platform UI so that we
# have more programmatic control of what happens, such as creating a resourceId for the LineItem
# so that we can uniquely identify an LTI linked resource after a course is copied in Canvas and
# the assignment IDs change, but we don't want to completely re-build all the Canvas UI stuff so
# folks will still be doing stuff in Canvas which means they could take an action that doesn't match
# our local database information (such as changing the title of an assignment), so the approach we're
# moving towards is having this be able to both setup and sync the local database information from
# the Canvas course information.
class InitializeNewCourse
  include Rails.application.routes.url_helpers

  InitializeNewCourseError = Class.new(StandardError)

  def initialize(new_course, section_names)
    @new_course = new_course
    @section_names = section_names
  end

  def run
    canvas_assignment_ids = initialize_assignments()

    if @section_names.present?
      canvas_section_ids = create_sections(canvas_assignment_ids)

      # Add an AssignmentOverride date object to each assignment for each section so that
      # the Edit Assignment Dates page shows the sections.
      CanvasAPI.client.create_assignment_override_placeholders(@new_course.canvas_course_id, canvas_assignment_ids, canvas_section_ids)
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

    # Attendance events don't need their LTI launch URLs updated, but do need
    # new CourseAttendanceEvent records in our DB.
    canvas_assignment_info.course_attendance_events_mapping.each do |canvas_assignment_id, course_attendance_event|
      initialize_new_course_attendance_event(canvas_assignment_id, course_attendance_event)
    end

    # Peer review
    if canvas_assignment_info.canvas_peer_reviews_assignment_id
      initialize_new_peer_review(canvas_assignment_info.canvas_peer_reviews_assignment_id)
    end

    # Fellow evalution
    if canvas_assignment_info.canvas_fellow_evaluation_assignment_id
      initialize_new_fellow_evaluation(canvas_assignment_info.canvas_fellow_evaluation_assignment_id)
    end

    # Waivers, Modules, Pre-, and Post-Accelerator assignments don't need their
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

  def initialize_new_peer_review(canvas_assignment_id)
    CanvasAPI.client.update_assignment_lti_launch_url(
      @new_course.canvas_course_id,
      canvas_assignment_id,
      new_course_peer_review_submission_url(@new_course, protocol: 'https'),
    )
  end

  def initialize_new_fellow_evaluation(canvas_assignment_id)
    CanvasAPI.client.update_assignment_lti_launch_url(
      @new_course.canvas_course_id,
      canvas_assignment_id,
      new_course_fellow_evaluation_submission_url(@new_course, protocol: 'https'),
    )
  end

  def create_sections(canvas_assignment_ids)
    canvas_section_ids = []
    @section_names.each do |sname|
      cs = CanvasAPI.client.create_lms_section(course_id: @new_course.canvas_course_id, name: sname)
      canvas_section_ids << cs.id
      ps = Section.create!(name: cs.name, course_id: @new_course.id, canvas_section_id: cs.id)
    end
    canvas_section_ids
  end

end
