class CreateProjects < ActiveRecord::Migration[6.0]
  def change
    create_table :projects do |t|
      t.belongs_to :course_module, foreign_key: true
      t.string :name, null: false
      t.integer :points_possible
      t.boolean :grades_muted, null: false, default: false
      t.datetime :grades_published_at
      t.timestamps
    end
  end
end
