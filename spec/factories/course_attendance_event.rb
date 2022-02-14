FactoryBot.define do
  factory :course_attendance_event do
    sequence(:canvas_assignment_id)
    association :course, factory: :course
    association :attendance_event, factory: :attendance_event

    factory :learning_lab_course_attendance_event do
      association :attendance_event, factory: :learning_lab_attendance_event
    end

    factory :mock_interviews_course_attendance_event do
      association :attendance_event, factory: :mock_interviews_attendance_event
    end

    factory :one_on_one_course_attendance_event do
      association :attendance_event, factory: :one_on_one_attendance_event
    end

  end
end
