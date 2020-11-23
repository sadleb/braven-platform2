class CreatePeerReviewSubmissions < ActiveRecord::Migration[6.0]
  def change
    create_table :peer_review_submissions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :base_course, null: false, foreign_key: true
    end
  end
end
