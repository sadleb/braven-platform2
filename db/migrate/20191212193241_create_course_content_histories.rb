class CreateCourseContentHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :course_content_histories do |t|
      t.references :course_content, null: false, foreign_key: true
      t.string :title
      t.text :body

      t.timestamps
    end
  end
end
