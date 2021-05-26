class RenamePeerReviewToCapstoneEvaluation < ActiveRecord::Migration[6.1]
  def change
    rename_table :peer_review_questions, :capstone_evaluation_questions
    rename_table :peer_review_submissions, :capstone_evaluation_submissions

    remove_index :peer_review_submission_answers,
      name: :index_peer_review_submission_answers_on_peer_review_question_id
    rename_table :peer_review_submission_answers, :capstone_evaluation_submission_answers
    rename_column :capstone_evaluation_submission_answers,
      :peer_review_question_id,
      :capstone_evaluation_question_id
    rename_column :capstone_evaluation_submission_answers,
      :peer_review_submission_id,
      :capstone_evaluation_submission_id
    add_index :capstone_evaluation_submission_answers,
      :capstone_evaluation_question_id,
      name: :index_capstone_eval_answers_questions_1
  end
end
