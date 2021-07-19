class CreateCanvasRubric < ActiveRecord::Migration[6.1]
  def change
    # Don't create an `id` primary key column, since it serves no purpose
    # here and would only slow down inserting new rows by including an
    # additional unique constraint check on each insert.
    create_table :canvas_rubrics, id: false do |t|
      t.bigint :canvas_rubric_id, null: false, index: { unique: true }
      t.float :points_possible
      t.string :title

      # Set a timestamp default so we can upsert easier.
      t.timestamps({default: -> { "CURRENT_TIMESTAMP" }})
    end
  end
end
