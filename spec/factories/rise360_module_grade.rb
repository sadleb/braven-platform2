FactoryBot.define do
  factory :rise360_module_grade do
    association :user, factory: :fellow_user
    course_rise360_module_version
    grade_manually_overridden { false }

    factory :rise360_module_grade_overridden do
      grade_manually_overridden { true }
    end
  end
end
