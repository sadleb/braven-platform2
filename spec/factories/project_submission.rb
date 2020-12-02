FactoryBot.define do
  factory :project_submission do
    user { build :fellow_user, section: build(:section) }
    course_project_version { build :course_project_version }
  end
end

