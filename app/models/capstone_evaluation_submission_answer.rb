# This it our custom key-value model for storing responses to capstone evaluation submissions.
# This is **not** a general-purpose key-value store.
class CapstoneEvaluationSubmissionAnswer < ApplicationRecord
  belongs_to :capstone_evaluation_submission
  belongs_to :capstone_evaluation_question
  belongs_to :for_user, class_name: "User"

  alias_attribute :question, :capstone_evaluation_question
  alias_attribute :submission, :capstone_evaluation_submission
  has_one :user, through: :capstone_evaluation_submission

  validates :capstone_evaluation_submission_id, :for_user_id, :capstone_evaluation_question_id, :input_value, presence: true
end
