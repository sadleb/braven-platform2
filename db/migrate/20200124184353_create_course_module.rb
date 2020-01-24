class CreateCourseModule < ActiveRecord::Migration[6.0]
  def change
    create_table :course_modules do |t|
      t.belongs_to :program, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false
      t.float :percent_of_grade
      t.timestamps
    end
  end
end
