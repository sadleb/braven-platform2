FactoryBot.define do
  factory :rubric_row_category do
    sequence(:name) { |i| "Category #{i}" }
    sequence(:position)

    rubric
  end
end

