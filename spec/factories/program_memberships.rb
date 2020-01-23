FactoryBot.define do
  factory :program_membership do
    association :user
    association :program
    association :role
  end
end
