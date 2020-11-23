# This it our custom key-value model for storing responses to peer review submissions.
# This is **not** a general-purpose key-value store.
class PeerReviewSubmissionAnswer < ApplicationRecord
  belongs_to :peer_review_submission
  belongs_to :peer_review_question
  belongs_to :for_user, class_name: "User"

  alias_attribute :question, :peer_review_question
  alias_attribute :submission, :peer_review_submission
  has_one :user, through: :peer_review_submission

  validates :peer_review_submission_id, :for_user_id, :peer_review_question_id, :input_value, presence: true
end
