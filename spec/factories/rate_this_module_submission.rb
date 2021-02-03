FactoryBot.define do
  factory :rate_this_module_submission do
    association :user, factory: :fellow_user
    course_rise360_module_version
  end
end

