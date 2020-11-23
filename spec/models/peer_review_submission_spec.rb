require 'rails_helper'
require 'lti_advantage_api'
require 'lti_score'

RSpec.describe PeerReviewSubmission, type: :model do

  # Associations
  it { should belong_to :user }
  it { should belong_to :course }

  # Validations
  it { should validate_presence_of :user_id }
  it { should validate_presence_of :base_course_id }
  
  context 'valid peer_review_submission' do
    let!(:user) { create(:fellow_user) }
    let(:peer_review_submission) { create(:peer_review_submission, user: user) }

    describe '#valid?' do
      it 'allows saving' do
        expect { peer_review_submission.save! }.to_not raise_error
      end
    end

    describe '#answers' do
      let(:peer_review_submission_answer) { create(
        :peer_review_submission_answer,
        peer_review_submission: peer_review_submission,
      ) }

      subject { peer_review_submission.answers.first }
      it { should eq(peer_review_submission_answer) }
    end

    describe '#save_answers!' do
      let(:question_1) { create(:peer_review_question) }
      let(:question_2) { create(:peer_review_question) }
      let(:peer_user_1) { create(:peer_user) }
      let(:peer_user_2) { create(:peer_user, canvas_user_id: '5432') }
      let(:peer_review_params_hash) { {
        peer_user_1.id.to_s => {
          question_1.id.to_s => 'My input 1',
          question_2.id.to_s => 'My input 2',
        },
        peer_user_2.id.to_s => {
          question_1.id.to_s => 'My input 3',
          question_2.id.to_s => 'My input 4',
        },
      } }

      it 'creates new answers' do
        expect {
          peer_review_submission.save_answers!(peer_review_params_hash)
        }.to change(PeerReviewSubmissionAnswer, :count).by(4)
      end

      it 'attaches the answers to the submission' do
        peer_review_submission.save_answers!(peer_review_params_hash)
        expect(peer_review_submission.answers.count).to eq(4)
      end
    end
  end
end
