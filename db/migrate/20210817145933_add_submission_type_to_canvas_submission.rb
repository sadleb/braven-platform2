class AddSubmissionTypeToCanvasSubmission < ActiveRecord::Migration[6.1]
  def change
    add_column :canvas_submissions, :submission_type, :string
  end
end
