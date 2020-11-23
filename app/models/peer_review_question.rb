class PeerReviewQuestion < ApplicationRecord
  has_many :peer_review_submission_answers
  alias_attribute :answers, :peer_review_submission_answers

  validates :text, presence: true
end
