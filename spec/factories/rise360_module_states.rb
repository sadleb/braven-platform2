FactoryBot.define do
  factory :rise360_module_state do
    user { build(:registered_user) }
    sequence(:activity_id) { |i| "MyString#{i}" }
    sequence(:canvas_course_id)
    sequence(:canvas_assignment_id)

    state_id { 'MyState' }
    value { 'test state value' }
  end
end
