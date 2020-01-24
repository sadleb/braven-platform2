class CreateLessons < ActiveRecord::Migration[6.0]
  def change
    create_table :lessons do |t|
      t.belongs_to :course_module, foreign_key: true
      t.string :name, null: false
      t.integer :points_possible
      t.timestamps
    end
  end
end
