class AddMockInterviewsEventTypeToAttendanceEvents < ActiveRecord::Migration[6.1]
  def up
   constraint_sql = <<~SQL
     event_type IN (
        '#{AttendanceEvent::LEARNING_LAB}',
        '#{AttendanceEvent::ORIENTATION}',
        '#{AttendanceEvent::LEADERSHIP_COACH_1_1}',
        '#{AttendanceEvent::MOCK_INTERVIEWS}'
      )
    SQL
    remove_check_constraint :attendance_events, name: 'chk_attendance_events_event_type'
    add_check_constraint :attendance_events, constraint_sql, name: 'chk_attendance_events_event_type'

    AttendanceEvent.where("title LIKE '%Mock Interview%'")
      .update_all(event_type: AttendanceEvent::MOCK_INTERVIEWS)
  end

  def down
    AttendanceEvent.where(event_type: AttendanceEvent::MOCK_INTERVIEWS)
      .update_all(event_type: AttendanceEvent::LEARNING_LAB)

    constraint_sql = <<~SQL
      event_type IN (
        '#{AttendanceEvent::LEARNING_LAB}',
        '#{AttendanceEvent::ORIENTATION}',
        '#{AttendanceEvent::LEADERSHIP_COACH_1_1}'
      )
    SQL
    remove_check_constraint :attendance_events, name: 'chk_attendance_events_event_type'
    add_check_constraint :attendance_events, constraint_sql, name: 'chk_attendance_events_event_type'
  end
end
