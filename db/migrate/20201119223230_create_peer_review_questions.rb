class CreatePeerReviewQuestions < ActiveRecord::Migration[6.0]
  def change
    create_table :peer_review_questions do |t|
      t.string :text, null: false
    end
  end
end
