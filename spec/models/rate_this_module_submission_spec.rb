require 'rails_helper'

RSpec.describe RateThisModuleSubmission, type: :model do
  subject { create(:rate_this_module_submission) }

  # Associations
  it { should belong_to :user }
  it { should belong_to :course_rise360_module_version }
  it { should have_one :course }
  it { should have_one :rise360_module_version }
  it { should have_many :rate_this_module_submission_answers }

  # Validations
  it { should validate_presence_of :user }
  it { should validate_presence_of :course_rise360_module_version }
  it { should validate_uniqueness_of(:user).scoped_to(:course_rise360_module_version_id) }

  let(:rate_this_module_submission) { create(:rate_this_module_submission) }

  describe '#save_answers!' do
    subject { rate_this_module_submission.save_answers!(answers) }

    shared_examples 'saves the answers to the submission' do
      scenario 'should not raise error' do
        expect { subject }.not_to raise_error
      end

      scenario 'create new answers' do
        expect {
          subject
        }.to change(RateThisModuleSubmissionAnswer, :count).by(answers.count)
      end
    end

    context 'with empty answers' do
      let(:answers) { {
        'module_score': '',
        'module_feedback': '',
      } }
      it_behaves_like 'saves the answers to the submission'
    end

    context 'with filled answers' do
      let(:answers) { {
        'module_score': '5',
        'module_feedback': 'It was ok',
      } }
      it_behaves_like 'saves the answers to the submission'
    end
  end
end
