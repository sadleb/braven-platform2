class RemoveOldCourseColumnsFromCustomContents < ActiveRecord::Migration[6.0]
  def change
    remove_column :custom_contents, :course_id, :integer
    remove_column :custom_contents, :secondary_id, :string
    remove_column :custom_contents, :course_name, :string
  end
end
