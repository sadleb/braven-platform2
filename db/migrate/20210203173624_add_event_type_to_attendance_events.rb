class AddEventTypeToAttendanceEvents < ActiveRecord::Migration[6.0]
  def change
    add_column :attendance_events, :event_type, :string
  end
end
