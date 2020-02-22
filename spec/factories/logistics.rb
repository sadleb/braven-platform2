FactoryBot.define do
  factory :logistic do
    day_of_week { 'Tuesday' }
    time_of_day { '8:00pm' }

    association :program, factory: :program
  end
end
