class CreateProjects < ActiveRecord::Migration[6.0]
  def change
    create_table :projects do |t|
      t.belongs_to :grade_category, foreign_key: true, null: false
      t.string :name, null: false
      t.integer :points_possible, null: false
      t.float :percent_of_grade_category, null: false
      t.boolean :grades_muted, null: false, default: false
      t.datetime :grades_published_at
      t.timestamps
    end
  end
end
