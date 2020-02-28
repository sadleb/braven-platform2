FactoryBot.define do
  factory :rubric_row_grade do
    points_given { 10 }

    rubric_row
    rubric_grade
  end
end

