FactoryBot.define do
  factory :project_submission do
    user { build :fellow_user, section: build(:section) }
    course_project_version { build :course_project_version }
    is_submitted { false }

    factory :project_submission_submitted do
      is_submitted { true }
      uniqueness_condition { nil }
    end
  end
end
