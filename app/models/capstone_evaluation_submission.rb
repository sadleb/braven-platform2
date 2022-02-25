class CapstoneEvaluationSubmission < ApplicationRecord
  belongs_to :user
  belongs_to :course, foreign_key: :course_id, class_name: "Course"

  has_many :capstone_evaluation_submission_answers
  alias_attribute :answers, :capstone_evaluation_submission_answers

  validates :user_id, :course_id, presence: true

  scope :graded, -> { where(new: false) }
  scope :ungraded, -> { where(new: true) }

  # Takes a nested hash like:
  #   { for_user_id => { capstone_evaluation_question_id: input_value (string) } }
  # and adds them as CapstoneEvaluationSubmissionAnswers to this submission.
  def save_answers!(input_values_by_user_and_question)
    transaction do
      save!
      input_values_by_user_and_question.map do |for_user_id, answers|
        answers.map do |capstone_evaluation_question_id, input_value|
          CapstoneEvaluationSubmissionAnswer.create!(
            capstone_evaluation_submission: self,
            for_user_id: for_user_id,
            capstone_evaluation_question_id: capstone_evaluation_question_id,
            input_value: input_value,
          )
        end
      end
    end
  end
end
