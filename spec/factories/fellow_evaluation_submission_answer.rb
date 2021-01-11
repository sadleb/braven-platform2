FactoryBot.define do
  factory :fellow_evaluation_submission_answer do
    fellow_evaluation_submission
    association :for_user, factory: :fellow_user
    input_name { 'would-hire-entry-level-role' }
    input_value { 'This is my review of my Fellow' }
  end
end
