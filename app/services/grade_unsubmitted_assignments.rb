# frozen_string_literal: true

# Grade unsubmitted LTI assignments by setting the grade to zero if the due date
# has passed. The Canvas gradebook is set to automatically give zeros
# for missing assignments, but it doesn't work for LTI submitted 
# assignments. This task runs nightly. 
require 'salesforce_api'
require 'canvas_api'

class GradeUnsubmittedAssignments
  def initialize
  end

  def run
    Honeycomb.start_span(name: 'grade_unsubmitted_assignments.run') do
      # From the list of "running" "programs" in Salesforce and those that have recently ended,
      # fetch a list of "accelerator" (non-LC) courses.
      #
      # We also get recently ended programs b/c we want to keep grading until we're sure that
      # the final grades have been sent to the university.
      # https://app.asana.com/0/1201131148207877/1200788567441198
      canvas_course_ids = SalesforceAPI.client
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
    assignment_ids = CanvasAPI.client.get_assignments(course.canvas_course_id)
      .filter_map { |a| assignment_filter(a) }

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

  def assignment_filter(assignment)
    return false unless assignment['submission_types'].include?('external_tool')
    return false unless assignment['published'] == true
    assignment['id']
  end
end
