# frozen_string_literal: true

class AttendanceEventSubmissionAnswer < ApplicationRecord
  belongs_to :attendance_event_submission
  alias_attribute :submission, :attendance_event_submission

  belongs_to :for_user, class_name: 'User'

  has_one :user, through: :attendance_event_submission
end
