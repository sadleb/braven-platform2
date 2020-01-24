class CreateRubricRowCategories < ActiveRecord::Migration[6.0]
  def change
    create_table :rubric_row_categories do |t|
      t.belongs_to :rubric, foreign_key: true, null: false
      t.string :name, null: false
      t.integer :position, null: false
      t.timestamps
    end
  end
end
