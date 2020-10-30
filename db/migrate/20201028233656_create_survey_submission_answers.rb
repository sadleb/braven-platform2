class CreateSurveySubmissionAnswers < ActiveRecord::Migration[6.0]
  def change
    create_table :survey_submission_answers do |t|
      t.belongs_to :survey_submission, foreign_key: true, null: false
      t.string :input_name, null: false
      t.string :input_value, null: true
      t.timestamps
    end
  end
end
