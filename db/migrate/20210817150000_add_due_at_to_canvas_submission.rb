class AddDueAtToCanvasSubmission < ActiveRecord::Migration[6.1]
  def change
    add_column :canvas_submissions, :due_at, :datetime, default: nil
  end
end
