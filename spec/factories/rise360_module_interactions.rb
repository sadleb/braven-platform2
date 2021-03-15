FactoryBot.define do
  factory :rise360_module_interaction do
    user { build(:registered_user) }
    activity_id { "MyString" }
    canvas_course_id { 10 }
    canvas_assignment_id { 20 }

    factory :progressed_module_interaction do
      verb { Rise360ModuleInteraction::PROGRESSED }
      progress { 0 }

      factory :ungraded_progressed_module_interaction do
        # new: true is the default
      end

      factory :graded_progressed_module_interaction do
       # add_attributoe(:new) { false } # I think "new" is a reserved word, but this still wasn't working.
        after(:create) do |ri, evaluator|
          ri.update!(new: false)
        end
      end
    end

    factory :answered_module_interaction do
      verb { Rise360ModuleInteraction::ANSWERED }
      success { true }

      factory :ungraded_answered_module_interaction do
        # new: true is the default
      end

      factory :graded_answered_module_interaction do
       # add_attributoe(:new) { false } # I think "new" is a reserved word, but this still wasn't working.
        after(:create) do |ri, evaluator|
          ri.update!(new: false)
        end
      end
    end
  end
end
