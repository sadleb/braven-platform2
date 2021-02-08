FactoryBot.define do
  factory :attendance_event do
    sequence(:title) { |i| "Attendance Event ##{i}" }

    factory :learning_lab_attendance_event do
      title { 'CLASS: Learning Lab 2: Lead Authentically' }
      event_type { AttendanceEvent::STANDARD_EVENT }
    end

    factory :one_on_one_attendance_event do
      title { 'TODO: Complete 1:1 with your Leadership Coach' }
      event_type { AttendanceEvent::SIMPLE_EVENT }
    end
  end
end
