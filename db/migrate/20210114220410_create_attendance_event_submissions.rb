class CreateAttendanceEventSubmissions < ActiveRecord::Migration[6.0]
  def change
    create_table :attendance_event_submissions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :course_attendance_event, null: false, foreign_key: true, index: { name: :index_submissions_on_course_attendance_event_id }
      t.timestamps
    end
  end
end
