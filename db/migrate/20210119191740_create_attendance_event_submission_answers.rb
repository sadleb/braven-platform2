class CreateAttendanceEventSubmissionAnswers < ActiveRecord::Migration[6.0]
  def change
    create_table :attendance_event_submission_answers do |t|
      t.references :attendance_event_submission, foreign_key: true, null: false, index: { name: 'index_attendance_event_submission_answers_on_submission_id'}
      t.references :for_user, foreign_key: { to_table: :users }, null: false
      t.boolean :in_attendance
      t.boolean :late
      t.string :absence_reason
      t.timestamps
    end
  end
end
