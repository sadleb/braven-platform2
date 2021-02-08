# frozen_string_literal: true

class AttendanceEventSubmission < ApplicationRecord
  belongs_to :user
  belongs_to :course_attendance_event

  has_one :course, through: :course_attendance_event
  has_one :attendance_event, through: :course_attendance_event
  has_many :attendance_event_submission_answers
  alias_attribute :answers, :attendance_event_submission_answers

  validates :user, :course_attendance_event, presence: true

  # Takes a nested hash like:
  #   { for_user_id => {
  #       in_attendance: ?boolean,
  #       late: ?boolean,
  #       absence_reason: ?string } }
  # and adds them as AttendanceEventSubmissionAnswers to this submission.
  def save_answers!(attendance_status_by_user, user)
    transaction do
      # Update who's taking attendance
      update!(user: user)
      attendance_status_by_user.map do |for_user_id, attendance_status|
        answer = AttendanceEventSubmissionAnswer.find_or_create_by!(
          attendance_event_submission: self,
          for_user_id: for_user_id,
        )
        answer.update!(
          in_attendance: attendance_status[:in_attendance],
          late: attendance_status[:late],
          absence_reason: attendance_status[:absence_reason],
        )
      end
    end
    self
  end

  # Should this event submission render with the simple checkbox-only form?
  def simple_form?
    attendance_event.event_type&.to_sym == AttendanceEvent::SIMPLE_EVENT
  end
end
