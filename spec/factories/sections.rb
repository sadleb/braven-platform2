FactoryBot.define do
  factory :section do
    sequence(:name) { |i| "Section Name #{i}" }

    association :program, factory: :program
    association :logistic, factory: :logistic
  end
end
