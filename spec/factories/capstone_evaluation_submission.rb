FactoryBot.define do
  factory :capstone_evaluation_submission do
    course
    association :user, factory: :registered_user
    transient do
      section { build(:section, course: course) }
    end

    factory :ungraded_capstone_evaluation_submission do
      # new: true is the default
    end

    factory :graded_capstone_evaluation_submission do
     # add_attribute(:new) { false } # I think "new" is a reserved word, but this still wasn't working.
      after(:create) do |ri, evaluator|
        ri.update!(new: false)
      end
    end

    after :create do |prs, options|
      prs.user.add_role RoleConstants::STUDENT_ENROLLMENT, options.section
    end
  end
end

