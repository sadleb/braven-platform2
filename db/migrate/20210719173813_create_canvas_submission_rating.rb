class CreateCanvasSubmissionRating < ActiveRecord::Migration[6.1]
  def change
    create_table :canvas_submission_ratings do |t|
      t.bigint :canvas_submission_id, null: false
      t.string :canvas_criterion_id, null: false
      t.string :canvas_rating_id, null: false
      t.string :comments
      t.float :points

      # Set a timestamp default so we can upsert easier.
      t.timestamps({default: -> { "CURRENT_TIMESTAMP" }})

      t.index [:canvas_submission_id, :canvas_rating_id, :canvas_criterion_id],
        unique: true,
        name: 'index_canvas_submission_ratings_unique_1'
    end
  end
end
