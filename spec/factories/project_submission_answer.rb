FactoryBot.define do
  factory :project_submission_answer do
    project_submission
    sequence(:input_name) { |i| "input_#{i}" }
    sequence(:input_value) { |i| "value #{i}" }
  end
end
