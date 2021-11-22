# frozen_string_literal: true

# Computes attendance grades based on AttendanceEventSubmissionAnswer
module AttendanceGradeCalculator
  # Returns a hash of { canvas_user_id => attendance grade } for answers
  # attached AttendanceEventSubmission for folks who have a Canvas account.
  # For folks that aren't in Canvas yet, They will get their grades computed
  # when they do register. See: grade_attendance_for_user_job
  def self.compute_grades(attendance_event_submission)
    attendance_event_submission.answers.filter_map { |answer|
      if answer.for_user.canvas_user_id.present?
        [answer.for_user.canvas_user_id, compute_grade(answer)]
      end
    }.to_h
  end

  # Returns string % grade of an AttendanceEventSubmissionAnswer
  def self.compute_grade(attendance_event_submission_answer)
    attendance_event_submission_answer.in_attendance ? '100%' : '0%'
  end
end
