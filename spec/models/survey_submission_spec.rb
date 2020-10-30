require 'rails_helper'

RSpec.describe SurveySubmission, type: :model do
  
  describe '#valid?' do
    let(:survey_submission) { build(:survey_submission) } 

    context 'when valid' do
      it 'allows saving' do
        expect { survey_submission.save! }.to_not raise_error
      end
    end

    context 'when no associated user' do
      it 'disallows saving' do
        survey_submission.user = nil
        expect { survey_submission.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when no associated project' do
      it 'disallows saving' do
        survey_submission.base_course_custom_content_version = nil
        expect { survey_submission.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe '#answers' do
    let(:survey_submission) { create :survey_submission }
    let(:survey_submission_answer) { create(
      :survey_submission_answer,
      survey_submission: survey_submission,
    ) }

    subject { survey_submission.answers.first }
    it { should eq(survey_submission_answer) }
  end

  describe '#save_answers' do
    let(:input_name) { 'test_input_name' }
    let(:input_value) { 'This is my test survey response!' }
    let(:survey_submission) { create :survey_submission }

    it 'adds answers to the submission' do
      expect {
        survey_submission.save_answers!({ input_name => input_value })
      }.to change(SurveySubmissionAnswer, :count).by(1)

      expect(survey_submission.answers.first.input_name).to eq(input_name)
      expect(survey_submission.answers.first.input_value).to eq(input_value)
    end
  end
end
