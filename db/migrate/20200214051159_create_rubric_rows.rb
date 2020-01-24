class CreateRubricRows < ActiveRecord::Migration[6.0]
  def change
    create_table :rubric_rows do |t|
      t.belongs_to :rubric_row_category, foreign_key: true, null: false
      t.string :criterion, null: false
      t.integer :points_possible, null: false
      t.integer :position, null: false
      t.timestamps
    end
  end
end
