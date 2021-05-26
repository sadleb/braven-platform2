FactoryBot.define do
  factory :capstone_evaluation_submission_answer do
    capstone_evaluation_submission
    association :for_user, factory: :peer_user
    capstone_evaluation_question
    input_value { 'this is my answer' }
  end
end
