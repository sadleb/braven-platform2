class PeerReviewSubmission < ApplicationRecord
  belongs_to :user
  belongs_to :course, foreign_key: :course_id, class_name: "Course"

  has_many :peer_review_submission_answers
  alias_attribute :answers, :peer_review_submission_answers

  validates :user_id, :course_id, presence: true

  # Takes a nested hash like:
  #   { for_user_id => { peer_review_question_id: input_value (string) } }
  # and adds them as PeerReviewSubmissionAnswers to this submission.
  def save_answers!(input_values_by_user_and_question)
    transaction do
      save!
      input_values_by_user_and_question.map do |for_user_id, answers|
        answers.map do |peer_review_question_id, input_value|
          PeerReviewSubmissionAnswer.create!(
            peer_review_submission: self,
            for_user_id: for_user_id,
            peer_review_question_id: peer_review_question_id,
            input_value: input_value,
          )
        end
      end
    end
  end
end
