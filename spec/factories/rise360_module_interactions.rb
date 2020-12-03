FactoryBot.define do
  factory :rise360_module_interaction do
    user { build(:registered_user) }
    activity_id { "MyString" }
    canvas_course_id { 10 }
    canvas_assignment_id { 20 }

    factory :progressed_module_interaction do
      verb { Rise360ModuleInteraction::PROGRESSED }
      progress { 0 }
    end

    factory :answered_module_interaction do
      verb { Rise360ModuleInteraction::ANSWERED }
      success { true }
    end
  end
end
