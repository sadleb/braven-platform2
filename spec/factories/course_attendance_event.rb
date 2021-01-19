FactoryBot.define do
  factory :course_attendance_event do
    sequence(:canvas_assignment_id)
    association :course, factory: :course
    association :attendance_event, factory: :attendance_event
  end
end
