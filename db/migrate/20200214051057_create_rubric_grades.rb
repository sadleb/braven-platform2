class CreateRubricGrades < ActiveRecord::Migration[6.0]
  def change
    create_table :rubric_grades do |t|
      t.belongs_to :project_submission, foreign_key: true, null: false, index: { unique: true }
      t.belongs_to :rubric, foreign_key: true, null: false
      t.timestamps
    end
  end
end
