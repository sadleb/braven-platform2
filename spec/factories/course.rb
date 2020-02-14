FactoryBot.define do
  factory :course do
    sequence(:name) { |i| "Program #{i}" }
    sequence(:term) { |i| "Term #{i}" }

    association :organization, factory: :organization
  end
end
