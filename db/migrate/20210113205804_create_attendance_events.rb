class CreateAttendanceEvents < ActiveRecord::Migration[6.0]
  def change
    create_table :attendance_events do |t|
      t.string :title, null: false
      t.timestamps
    end
  end
end
