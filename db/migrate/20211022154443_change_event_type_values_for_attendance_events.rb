class ChangeEventTypeValuesForAttendanceEvents < ActiveRecord::Migration[6.1]
  def up
    # We're repurposing the event_type column of AttendanceEvent to be more specific since we
    # need to distinguish Orientation language from Learning Lab language and choose the proper
    # Zoom link to show.  Go change them all.
    AttendanceEvent.where(event_type: :StandardEvent).update_all(event_type: AttendanceEvent::LEARNING_LAB)
    AttendanceEvent.where(event_type: :SimpleEvent).update_all(event_type: AttendanceEvent::LEADERSHIP_COACH_1_1)
    AttendanceEvent.where(title: 'Orientation').update_all(event_type: AttendanceEvent::ORIENTATION)

    # Add a null: false constraint for event_type. We rely on it being set.
    change_column_null(:attendance_events, :event_type, false)

    add_check_constraint(:attendance_events,
      "event_type IN ('#{AttendanceEvent::LEARNING_LAB}', '#{AttendanceEvent::ORIENTATION}', '#{AttendanceEvent::LEADERSHIP_COACH_1_1}')",
      name: 'chk_attendance_events_event_type'
    )
  end

  def down
    remove_check_constraint(:attendance_events, name: 'chk_attendance_events_event_type')

    AttendanceEvent.where(event_type: [AttendanceEvent::LEARNING_LAB, AttendanceEvent::ORIENTATION])
      .update_all(event_type: :StandardEvent)
    AttendanceEvent.where(event_type: AttendanceEvent::LEADERSHIP_COACH_1_1)
      .update_all(event_type: :SimpleEvent)
  end
end
