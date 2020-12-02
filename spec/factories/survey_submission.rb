FactoryBot.define do
  factory :survey_submission do
    user { build :fellow_user, section: build(:section) }
    course_survey_version { build :course_survey_version }
  end
end

