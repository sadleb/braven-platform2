class CapstoneEvaluationQuestion < ApplicationRecord
  has_many :capstone_evaluation_submission_answers
  alias_attribute :answers, :capstone_evaluation_submission_answers

  validates :text, presence: true
end
