require 'rails_helper'

RSpec.describe PeerReviewSubmissionAnswer, type: :model do

  # Associations
  it { should belong_to :peer_review_submission }
  it { should belong_to :peer_review_question }
  it { should belong_to :for_user }

  # Validations
  it { should validate_presence_of :peer_review_submission_id }
  it { should validate_presence_of :peer_review_question_id }
  it { should validate_presence_of :for_user_id }
  it { should validate_presence_of :input_value }

  let!(:user) { create(:fellow_user) }
  let(:peer_review_submission) { create(:peer_review_submission, user: user) }
  let(:peer_review_submission_answer) { create(:peer_review_submission_answer, peer_review_submission: peer_review_submission) }

  describe "#save" do
    it 'allows saving' do
      expect { peer_review_submission_answer.save! }.to_not raise_error
    end
  end
end
