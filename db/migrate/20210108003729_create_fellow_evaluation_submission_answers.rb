class CreateFellowEvaluationSubmissionAnswers < ActiveRecord::Migration[6.0]
  def change
    create_table :fellow_evaluation_submission_answers do |t|
      t.references :fellow_evaluation_submission, null: false, foreign_key: true, index: { name: :index_fellow_evaluation_submission_answers_on_submission_id }
      t.references :for_user, null: false, foreign_key: { to_table: :users }
      t.string :input_name
      t.string :input_value
    end
  end
end
