class CreatePeerReviewSubmissionAnswers < ActiveRecord::Migration[6.0]
  def change
    create_table :peer_review_submission_answers do |t|
      t.references :peer_review_submission, null: false, foreign_key: true, index: { name: :index_peer_review_submission_answers_on_submission_id }
      t.references :for_user, null: false, foreign_key: { to_table: :users }
      t.string :question_name, null: false
      t.string :input_value
    end
  end
end
