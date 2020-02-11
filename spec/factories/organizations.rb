FactoryBot.define do
  factory :organization do
    sequence(:name) { |i| "Org Name #{i}" }
  end
end
