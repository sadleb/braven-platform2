# DEPRECATED: This feature has been removed. The models/tables are left
# in place for access to historical data.

# This it our custom key-value model for storing LC responses for Fellow
# Evaluations.
# This is **not** a general-purpose key-value store.
class FellowEvaluationSubmissionAnswer < ApplicationRecord
  belongs_to :fellow_evaluation_submission
  belongs_to :for_user, class_name: 'User'

  alias_attribute :submission, :fellow_evaluation_submission

  has_one :user, through: :fellow_evaluation_submission

  validates :fellow_evaluation_submission_id, :for_user_id, :input_name, :input_value, presence: true
end
