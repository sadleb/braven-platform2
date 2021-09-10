class AddCanvasGraderIdToCanvasSubmission < ActiveRecord::Migration[6.1]
  def change
    add_column :canvas_submissions, :canvas_grader_id, :bigint, default: nil
  end
end
