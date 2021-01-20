FactoryBot.define do
  factory :attendance_event_submission_answer do
    # This factory's associations intentionally left blank.
    # Pass in `attendance_event_submission` and `for_user` explicitly.
    factory :unsubmitted_attendance_event_submission_answer do
      in_attendance { nil }
      late { nil }
      absence_reason { nil }
    end

    factory :absent_attendance_event_submission_answer do
      in_attendance { false }
      late { nil }
      absence_reason { 'my reason for being absent' }
    end

    factory :present_attendance_event_submission_answer do
      in_attendance { true }
      late { false }
      absence_reason { nil }
    end

    factory :late_attendance_event_submission_answer do
      in_attendance { true }
      late { true }
      absence_reason { nil }
    end
  end
end
