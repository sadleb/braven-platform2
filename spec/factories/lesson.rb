FactoryBot.define do
  factory :lesson do
    sequence(:name) { |i| "Lesson Name #{i}" }
    points_possible { 10 }
    percent_of_grade_category { 0.5 }

    grade_category
  end
end
