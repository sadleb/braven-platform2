# frozen_string_literal: true

# This model represents a basic key-value store for the xAPI "state" API.
# For more information, see lib/lrs_xapi_mock.rb.
class Rise360ModuleState < ApplicationRecord
  belongs_to :user
  validates :user, :activity_id, :canvas_course_id, :canvas_assignment_id, :state_id, presence: true
  validates :state_id, uniqueness: {scope: [
    :user, :activity_id, :canvas_course_id, :canvas_assignment_id
  ]}
end
