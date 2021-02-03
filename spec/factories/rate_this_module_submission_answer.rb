FactoryBot.define do
  factory :rate_this_module_submission_answer do
    rate_this_module_submission
    input_name { 'module_score' }
    input_value { '20' }
  end
end
