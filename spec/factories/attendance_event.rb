FactoryBot.define do
  factory :attendance_event do
    sequence(:title) { |i| "Attendance Event ##{i}" }
    event_type { AttendanceEvent::LEARNING_LAB} # Default

    factory :learning_lab_attendance_event do
      title { 'CLASS: Learning Lab 2: Lead Authentically' }
      event_type { AttendanceEvent::LEARNING_LAB}
    end

    factory :orientation_attendance_event do
      title { 'Orientation' }
      event_type { AttendanceEvent::ORIENTATION }
    end

    factory :one_on_one_attendance_event do
      title { 'TODO: Complete 1:1 with your Leadership Coach' }
      event_type { AttendanceEvent::LEADERSHIP_COACH_1_1 }
    end
  end
end
