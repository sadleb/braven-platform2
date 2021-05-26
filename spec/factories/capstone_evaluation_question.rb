FactoryBot.define do
  factory :capstone_evaluation_question do
    sequence(:text) {|i| "Question text #{i}"}
  end
end
