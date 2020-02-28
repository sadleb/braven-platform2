FactoryBot.define do
  factory :project do
    sequence(:name) { |i| "Project Name #{i}" }
    points_possible { 10 }
    percent_of_grade_category { 0.5 }

    grade_category
  end
end
