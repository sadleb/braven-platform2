class CreateCourseAttendanceEvents < ActiveRecord::Migration[6.0]
  def change
    create_table :course_attendance_events do |t|
      t.references :attendance_event, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
      t.bigint :canvas_assignment_id, null: false
      t.timestamps
    end
  end
end
