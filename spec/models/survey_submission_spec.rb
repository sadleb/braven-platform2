require 'rails_helper'
require 'lti_advantage_api'
require 'lti_score'

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
        survey_submission.base_course_survey_version = nil
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
    let(:survey_answers) { {
      'input_name_1' => 'My Input 1',
      'input_name_2' => 'My input 2',
    } }

    let(:survey_submission) { create :survey_submission }

    it 'creates new answers' do
      expect {
        survey_submission.save_answers!(survey_answers)
      }.to change(SurveySubmissionAnswer, :count).by(survey_answers.length)
    end

    it 'attaches the answers to the submission' do
      survey_submission.save_answers!(survey_answers)
      expect(survey_submission.answers.length).to eq(survey_answers.length)
      survey_answers.each do |name, value|
          answer_saved = false;
          survey_submission.answers.each do |answer|
            if answer.input_name == name && answer.input_value == value
              answer_saved = true;
              break;
            end
          end
          expect(answer_saved).to eq(true)
      end
    end
  end
end
