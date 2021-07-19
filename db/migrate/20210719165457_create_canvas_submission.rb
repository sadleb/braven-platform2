class CreateCanvasSubmission < ActiveRecord::Migration[6.1]
  def change
    # Don't create an `id` primary key column, since it serves no purpose
    # here and would only slow down inserting new rows by including an
    # additional unique constraint check on each insert.
    create_table :canvas_submissions, id: false do |t|
      t.bigint :canvas_submission_id, null: false, index: { unique: true }
      t.bigint :canvas_assignment_id, null: false
      t.bigint :canvas_user_id, null: false
      t.bigint :canvas_course_id, null: false
      t.float :score
      t.string :grade
      t.datetime :graded_at
      t.boolean :late

      # Set a timestamp default so we can upsert easier.
      t.timestamps({default: -> { "CURRENT_TIMESTAMP" }})
    end
  end
end
