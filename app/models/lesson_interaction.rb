# frozen_string_literal: true
class LessonInteraction < ApplicationRecord
  PROGRESSED = 'http://adlnet.gov/expapi/verbs/progressed'
  ANSWERED = 'http://adlnet.gov/expapi/verbs/answered'

  belongs_to :user
  validates :user, :activity_id, :verb, :canvas_course_id, :canvas_assignment_id, presence: true

  scope :for_user_and_activity, -> (user_id, activity_id) do
    where(
      "activity_id LIKE ? AND user_id = ?",
      "#{activity_id}%",
      user_id,
    )
  end
end
