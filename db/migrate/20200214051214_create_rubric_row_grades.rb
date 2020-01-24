class CreateRubricRowGrades < ActiveRecord::Migration[6.0]
  def change
    create_table :rubric_row_grades do |t|
      t.belongs_to :rubric_grade, foreign_key: true, null: false
      t.belongs_to :rubric_row, foreign_key: true, null: false
      t.integer :points_given
      t.timestamps
    end
  end
end
