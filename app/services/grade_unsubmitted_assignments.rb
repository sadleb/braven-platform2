# frozen_string_literal: true

# Grade unsubmitted LTI assignments by setting the grade to zero if the due date
# has passed. The Canvas gradebook is set to automatically give zeros
# for missing assignments, but it doesn't work for LTI submitted 
# assignments. This task runs nightly. 
require 'salesforce_api'
require 'canvas_api'

class GradeUnsubmittedAssignments
  def initialize(canvas_course_ids=nil, filter_assignments=true)
    # If canvas_course_ids is nil, default to running/recently ended programs.
    @canvas_course_ids = canvas_course_ids
    @filter_assignments = filter_assignments
  end

  def run
    Honeycomb.start_span(name: 'grade_unsubmitted_assignments.run') do
      # From the list of "running" "programs" in Salesforce and those that have recently ended,
      # fetch a list of "accelerator" (non-LC) courses.
      #
      # We also get recently ended programs b/c we want to keep grading until we're sure that
      # the final grades have been sent to the university.
      # https://app.asana.com/0/1201131148207877/1200788567441198
      canvas_course_ids = @canvas_course_ids || SalesforceAPI.client
        .get_current_and_future_accelerator_canvas_course_ids(ended_less_than: 45.days.ago)

      Honeycomb.add_field('grade_unsubmitted_assignments.canvas_course_ids', canvas_course_ids)
      if canvas_course_ids.empty?
        Rails.logger.info("Exit early: no current/future accelerator programs with a Canvas course ID set.")
        return
      end

      courses = Course.where(canvas_course_id: canvas_course_ids)
      courses.each do |course|
        grade_unsubmitted_assignments(course)
      end
    end
  end

  def grade_unsubmitted_assignments(course)
    # Get all assignments for course and run through assignment filter
    assignments = CanvasAPI.client.get_assignments(course.canvas_course_id)
    assignment_ids = assignments.map { |a| a['id'] }

    if @filter_assignments
      assignment_ids = assignments.filter_map { |a| assignment_filter(a) }
    end

    if assignment_ids.empty?
      Rails.logger.info("Skip grading assignments for canvas_course = #{course.canvas_course_id}; no assignments to grade")
      return
    end

    # Get unsubmitted submissions for all of the above assignments
    submissions_by_assignment = CanvasAPI.client.get_unsubmitted_assignment_data(course.canvas_course_id, assignment_ids)

    submissions_by_assignment.each do |assignment_id, submissions|
      zero_out_grades(course.canvas_course_id, assignment_id, submissions)
    end
  end

  def zero_out_grades(canvas_course_id, canvas_assignment_id, submissions)
    submissions_to_grade = {}
    submissions.each do |submission|
      canvas_submission = CanvasSubmission.parse(submission)
      next unless canvas_submission.needs_zero_grade?

      submissions_to_grade[canvas_submission.canvas_user_id] = '0%'
    end

    if submissions_to_grade.present?
      CanvasAPI.client.update_grades(
        canvas_course_id,
        canvas_assignment_id,
        submissions_to_grade
      )
    end
  end

  # This filters out assignments that we don't want to automatically grade.
  # We only want to grade unsubmitted assignments (filters for unsubmitted
  # in the Canvas API call) that have an external_tool submission type and
  # are published. We also don't want to grade unsubmitted attendance events,
  # LCs should submit attendance. We don't want to grade assignments
  # where the grade posting policy is set to grade manually because LCs/TAs
  # could still be working on grading, so when they are finished grading they
  # need to update the grade posting policy to "manually" in order for
  # assignments to pass the filter and submit zeros for missing assignments.
  def assignment_filter(assignment)
    return false unless assignment['submission_types'].include?('external_tool')
    return false unless assignment['published']
    return false if CourseAttendanceEvent.where(canvas_assignment_id: assignment['id']).exists?
    return false if assignment['post_manually']
    assignment['id']
  end
end
