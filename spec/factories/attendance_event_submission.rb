FactoryBot.define do
  factory :attendance_event_submission do
    association :user
    association :course_attendance_event
  end
end

