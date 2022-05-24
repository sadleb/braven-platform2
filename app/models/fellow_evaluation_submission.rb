# DEPRECATED: This feature has been removed. The models/tables are left
# in place for access to historical data.

# This is created when a Leadership Coach reviews their Fellows in their
# Fellow Evaluation assignment.
class FellowEvaluationSubmission < ApplicationRecord
  belongs_to :user
  belongs_to :course

  has_many :fellow_evaluation_submission_answers
  alias_attribute :answers, :fellow_evaluation_submission_answers

  validates :user_id, :course_id, presence: true

  # Takes a nested hash like:
  #   { for_user_id => { input_name (string): input_value (string) } }
  # and adds them as FellowEvaluationSubmissionAnswers to this submission.
  def save_answers!(input_values_by_user_and_input_name)
    transaction do
      save!
      input_values_by_user_and_input_name.map do |for_user_id, answers|
        answers.map do |input_name, input_value|
          next unless input_value.present?
          FellowEvaluationSubmissionAnswer.create!(
            fellow_evaluation_submission: self,
            for_user_id: for_user_id,
            input_name: input_name,
            input_value: input_value,
          )
        end
      end
    end
  end
end
