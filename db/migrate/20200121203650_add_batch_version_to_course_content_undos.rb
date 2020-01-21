class AddBatchVersionToCourseContentUndos < ActiveRecord::Migration[6.0]
  def change
    add_column :course_content_undos, :batch_version, :integer
  end
end
