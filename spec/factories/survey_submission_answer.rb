FactoryBot.define do
  factory :survey_submission_answer do
    survey_submission { build :survey_submission }
    input_name { 'my_input_name'}
    input_value { 'this_is_my_answer' }
  end
end
