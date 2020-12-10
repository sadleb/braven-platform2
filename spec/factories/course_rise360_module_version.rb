FactoryBot.define do
  factory :course_rise360_module_version do
    sequence(:canvas_assignment_id)
    association :course, factory: :course
    rise360_module_version
  end
end
