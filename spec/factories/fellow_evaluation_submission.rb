FactoryBot.define do
  factory :fellow_evaluation_submission do
    course
    association :user, factory: :registered_user
    transient do
      section { build(:section, course: course) }
    end

    after :create do |submission, options|
      submission.user.add_role RoleConstants::STUDENT_ENROLLMENT, options.section
    end
  end
end

