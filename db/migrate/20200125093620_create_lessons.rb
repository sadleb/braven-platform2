class CreateLessons < ActiveRecord::Migration[6.0]
  def change
    create_table :lessons do |t|
      t.belongs_to :grade_category, foreign_key: true, null: false
      t.string :name, null: false
      t.integer :points_possible, null: false
      t.float :percent_of_grade_category, null: false
      t.timestamps
    end
  end
end
