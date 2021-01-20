# frozen_string_literal: true

class AttendanceEventSubmission < ApplicationRecord
  belongs_to :user
  belongs_to :course_attendance_event

  has_one :course, through: :course_attendance_event

  validates :user, :course_attendance_event, presence: true

  # Takes a nested hash like:
  #   { for_user_id => {
  #       in_attendance: ?boolean,
  #       late: ?boolean,
  #       absence_reason: ?string } }
  # and adds them as AttendanceEventSubmissionAnswers to this submission.
  def save_answers!(attendance_status_by_user)
    transaction do
      save!
      attendance_status_by_user.map do |for_user_id, attendance_status|
        AttendanceEventSubmissionAnswer.create!(
          attendance_event_submission: self,
          for_user_id: for_user_id,
          in_attendance: attendance_status[:in_attendance],
          late: attendance_status[:late],
          absence_reason: attendance_status[:absence_reason],
        )
      end
    end
    self
  end
end
