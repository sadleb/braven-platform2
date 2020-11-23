FactoryBot.define do
  factory :peer_review_question do
    sequence(:text) {|i| "Question text #{i}"}
  end
end
