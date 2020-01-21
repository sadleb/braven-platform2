class AddCourseContentUndosUniqueConstraint < ActiveRecord::Migration[6.0]
  def up
    add_index :course_content_undos, [:course_content_id, :version], :unique => true
  end

  def down
    remove_index :course_content_undos
  end
end
