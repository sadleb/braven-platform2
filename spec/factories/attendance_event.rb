FactoryBot.define do
  factory :attendance_event do
    sequence(:title) { |i| "Attendance Event ##{i}" }

    factory :learning_lab_attendance_event do
      title { 'CLASS: Learning Lab 2: Lead Authentically' }
    end
  end
end
