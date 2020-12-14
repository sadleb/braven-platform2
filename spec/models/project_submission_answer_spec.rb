require 'rails_helper'

RSpec.describe ProjectSubmissionAnswer, type: :model do

  subject { build(:project_submission_answer) }

  it { should validate_presence_of :project_submission }
  it { should validate_presence_of :input_name }
  it { should validate_uniqueness_of(:input_name).scoped_to(:project_submission_id) }

  describe '#valid?' do
    let(:project_submission) { create(:project_submission) }
    let(:project_submission_answer) { build(:project_submission_answer, project_submission: project_submission) }

    context 'when valid' do
      it 'allows saving' do
        expect { project_submission_answer.save! }.to_not raise_error
      end
    end

    context 'uniqueness constraint violated' do
      let(:input_name) { 'some-name' }
      let(:project_submission_answer) { build(:project_submission_answer, project_submission: project_submission, input_name: input_name) }

      it 'disallows saving' do
        create(
          :project_submission_answer, project_submission: project_submission, input_name: input_name
        )
        expect { project_submission_answer.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when submission is already submitted' do
      let(:project_submission) { create(:project_submission_submitted) }

      it 'disallows saving' do
        expect { project_submission_answer.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

  end
end
