class RemoveColumnsFromProjectSubmissions < ActiveRecord::Migration[6.0]
  def change
    remove_column :project_submissions, :submitted_at, :datetime
    remove_column :project_submissions, :graded_at, :datetime
    remove_column :project_submissions, :points_received, :float
  end
end
