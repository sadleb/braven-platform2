class CreateGradeCategories < ActiveRecord::Migration[6.0]
  def change
    create_table :grade_categories do |t|
      t.belongs_to :program, foreign_key: true, null: false
      t.string :name, null: false
      t.float :percent_of_grade
      t.timestamps
    end

  end
end
