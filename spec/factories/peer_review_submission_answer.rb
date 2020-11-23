FactoryBot.define do
  factory :peer_review_submission_answer do
    peer_review_submission
    association :for_user, factory: :peer_user
    peer_review_question
    input_value { 'this is my answer' }
  end
end
