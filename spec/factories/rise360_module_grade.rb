FactoryBot.define do
  factory :rise360_module_grade do
    association :user, factory: :fellow_user
    course_rise360_module_version
  end
end
