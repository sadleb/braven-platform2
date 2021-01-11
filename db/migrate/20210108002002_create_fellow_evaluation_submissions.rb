class CreateFellowEvaluationSubmissions < ActiveRecord::Migration[6.0]
  def change
    create_table :fellow_evaluation_submissions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
    end
  end
end
