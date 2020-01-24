class CreateRubricRowRatings < ActiveRecord::Migration[6.0]
  def change
    create_table :rubric_row_ratings do |t|
      t.belongs_to :rubric_row, foreign_key: true, null: false
      t.string :description, null: false
      t.integer :points_value, null: false
      t.timestamps
    end
  end
end
