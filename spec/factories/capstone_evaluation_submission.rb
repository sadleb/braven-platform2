FactoryBot.define do
  factory :capstone_evaluation_submission do
    course
    association :user, factory: :registered_user
    transient do
      section { build(:section, course: course) }
    end

    after :create do |prs, options|
      prs.user.add_role RoleConstants::STUDENT_ENROLLMENT, options.section
    end
  end
end

