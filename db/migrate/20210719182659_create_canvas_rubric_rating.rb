class CreateCanvasRubricRating < ActiveRecord::Migration[6.1]
  def change
    # Note Canvas has no table for this, the data is serialized inside
    # the Rubric model instead. We broke it out to make Periscope stuff
    # easier.
    create_table :canvas_rubric_ratings do |t|
      t.bigint :canvas_rubric_id, null: false
      t.string :canvas_criterion_id, null: false
      t.string :canvas_rating_id, null: false
      t.string :description
      t.string :long_description
      t.float :points

      # Set a timestamp default so we can upsert easier.
      t.timestamps({default: -> { "CURRENT_TIMESTAMP" }})

      t.index [:canvas_rubric_id, :canvas_criterion_id, :canvas_rating_id],
        unique: true,
        name: 'index_canvas_rubric_ratings_unique_1'
    end
  end
end
