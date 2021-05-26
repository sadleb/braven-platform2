require 'rails_helper'
require 'lti_advantage_api'
require 'lti_score'

RSpec.describe CapstoneEvaluationSubmission, type: :model do

  # Associations
  it { should belong_to :user }
  it { should belong_to :course }

  # Validations
  it { should validate_presence_of :user_id }
  it { should validate_presence_of :course_id }
  
  context 'valid capstone_evaluation_submission' do
    let!(:user) { create(:fellow_user) }
    let(:capstone_evaluation_submission) { create(:capstone_evaluation_submission, user: user) }

    describe '#valid?' do
      it 'allows saving' do
        expect { capstone_evaluation_submission.save! }.to_not raise_error
      end
    end

    describe '#answers' do
      let(:capstone_evaluation_submission_answer) { create(
        :capstone_evaluation_submission_answer,
        capstone_evaluation_submission: capstone_evaluation_submission,
      ) }

      subject { capstone_evaluation_submission.answers.first }
      it { should eq(capstone_evaluation_submission_answer) }
    end

    describe '#save_answers!' do
      let(:question_1) { create(:capstone_evaluation_question) }
      let(:question_2) { create(:capstone_evaluation_question) }
      let(:peer_user_1) { create(:peer_user) }
      let(:peer_user_2) { create(:peer_user, canvas_user_id: '5432') }
      let(:capstone_evaluation_params_hash) { {
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
          capstone_evaluation_submission.save_answers!(capstone_evaluation_params_hash)
        }.to change(CapstoneEvaluationSubmissionAnswer, :count).by(4)
      end

      it 'attaches the answers to the submission' do
        capstone_evaluation_submission.save_answers!(capstone_evaluation_params_hash)
        expect(capstone_evaluation_submission.answers.count).to eq(4)
      end
    end
  end
end
