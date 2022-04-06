# frozen_string_literal: true

# Computes attendance grades based on AttendanceEventSubmissionAnswer
module AttendanceGradeCalculator
  # Returns a hash of { canvas_user_id => attendance grade } for answers
  # attached to the AttendanceEventSubmission
  def self.compute_grades(attendance_event_submission)
    attendance_event_submission.answers.to_h { |answer|
      [answer.for_user.canvas_user_id, compute_grade(answer)]
    }
  end

  # Returns string % grade of an AttendanceEventSubmissionAnswer
  def self.compute_grade(attendance_event_submission_answer)
    attendance_event_submission_answer.in_attendance ? '100%' : '0%'
  end
end
