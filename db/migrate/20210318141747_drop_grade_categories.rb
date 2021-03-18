class DropGradeCategories < ActiveRecord::Migration[6.1]
  def change
    drop_table :grade_categories
  end
end
