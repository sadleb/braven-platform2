# frozen_string_literal: true

require 'canvas_api'

class GradeAttendanceForUserJob < ApplicationJob
  queue_as :low_priority

  # This grabs all existing attendance_event_submission_answers for this user
  # and course and updates their grade in Canvas for them. Note that their grades
  # should be updated in real-time when they are submitted. This job is intended
  # to cleanup grades that couldn't be submitted for some reason (e.g. they didn't
  # have a Canvas account yet)
  def perform(user, canvas_course_id)

    # Explicitly set the user context and course id since this is a background job.
    user.add_to_honeycomb_trace()
    Honeycomb.add_field('canvas.course.id', canvas_course_id.to_s)


    # Only grab the most recent answer per Canvas assignment (aka the last one created)
    # in this course.  Multiple people can submit attendance which which end up with
    # multiple answers for the same event (aka assignment) and the most recent should win.
    # This matches what we show in our data dashboards.
    assignment_grades = {}
    AttendanceEventSubmissionAnswer.where(for_user: user).order(:created_at).each do |answer|

      # Someone could be enrolled in multiple courses, so just skip answers for other ones.
      course_attendance_event = answer.submission.course_attendance_event
      next unless canvas_course_id = course_attendance_event.course.canvas_course_id

      assignment_grades[course_attendance_event.canvas_assignment_id] =
        AttendanceGradeCalculator.compute_grade(answer)
    end
    Honeycomb.add_field('grade_attendance_for_user.assignment_grades', assignment_grades)

    assignment_grades.each do |canvas_assignment_id, grade|
      # Note: we're using the async update_grades() method instead of the synchronous
      # one b/c this happens as we're creating their Canvas account and enrollng them.
      # Canvas would sometimes return a generic "An error occurred." response. Just
      # trying to make that less likely.
      CanvasAPI.client.update_grades(
        canvas_course_id,
        canvas_assignment_id,
        { user.canvas_user_id => grade }
      )
    end
  end

private

  # Don't enqueue the job unless there are attendance answers for this user
  # Note: I tested and this exception doesn't go to Sentry/Honeycomb. This seems like
  # a weird way to halt enqueuing but it's the only thing I could find that works.
  # See: https://andycroll.com/ruby/a-job-should-know-whether-to-run-itself/
  # Also: https://github.com/rails/rails/blob/main/activejob/test/jobs/abort_before_enqueue_job.rb
  # It results in the following message in the logs:
  # [ActiveJob] Failed enqueuing GradeAttendanceForUserJob to Async(low_priority), a before_enqueue callback halted the enqueuing execution.
  before_enqueue do |job|
    user = job.arguments.first
    throw(:abort) unless AttendanceEventSubmissionAnswer.where(for_user: user).exists?
  end

end
