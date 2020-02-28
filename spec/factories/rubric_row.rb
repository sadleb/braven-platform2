FactoryBot.define do
  factory :rubric_row do
    criterion { 'Criterion to get credit for this row.' }
    points_possible { 10 }
    sequence(:position)

    rubric_row_category
  end
end

