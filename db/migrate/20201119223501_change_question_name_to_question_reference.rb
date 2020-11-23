class ChangeQuestionNameToQuestionReference < ActiveRecord::Migration[6.0]
  def change
    remove_column :peer_review_submission_answers, :question_name
    add_reference :peer_review_submission_answers, :peer_review_question, foreign_key: true
  end
end
