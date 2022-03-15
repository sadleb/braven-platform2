class CreateCanvasAssignmentOverride < ActiveRecord::Migration[6.1]
  def change
    create_table :canvas_assignment_overrides do |t|
      t.bigint :canvas_assignment_override_id, null: false
      t.bigint :canvas_course_id, null: false
      t.bigint :canvas_assignment_id, null: false
      t.bigint :canvas_section_id
      t.bigint :canvas_user_id
      t.string :title
      t.datetime :due_at
      t.datetime :lock_at
      t.datetime :unlock_at
      t.boolean :all_day
      t.date :all_day_date

      # Set a timestamp default so we can upsert easier.
      t.timestamps(default: -> { "CURRENT_TIMESTAMP" })

      # Add a unique constraint that enforces uniqueness for [override, user]
      # and [override, section] pairs. Canvas AssignmentOverrides will always
      # only have a section or 1+ users, never both. Unique indexes treat null
      # as non-matching (e.g. two rows (1, null) and (1, null) will not violate
      # a uniqueness constraint), so we use COALESCE to get around that.
      t.index 'canvas_assignment_override_id, coalesce(canvas_section_id, -1), coalesce(canvas_user_id, -1)',
        unique: true,
        name: 'index_canvas_assignment_overrides_unique_1'
    end
  end
end
