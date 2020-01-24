class CreateRubrics < ActiveRecord::Migration[6.0]
  def change
    create_table :rubrics do |t|
      t.belongs_to :project, foreign_key: true, null: false, index: { unique: true }
      t.integer :points_possible, null: false
      t.timestamps
    end
  end
end
