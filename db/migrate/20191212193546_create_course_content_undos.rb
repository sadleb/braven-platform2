class CreateCourseContentUndos < ActiveRecord::Migration[6.0]
  def change
    create_table :course_content_undos do |t|
      t.references :course_content, null: false, foreign_key: true
      t.text :operation
      t.integer :version

      t.timestamps
    end
  end
end
