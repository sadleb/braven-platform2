require 'rails_helper'

RSpec.describe SurveySubmissionAnswer, type: :model do

  let(:survey_submission_answer) { build(:survey_submission_answer) } 

  describe "#save" do
    it 'allows saving' do
      expect { survey_submission_answer.save! }.to_not raise_error
    end

    it 'requires input_name' do
      survey_submission_answer.input_name = nil
      expect {
        survey_submission_answer.save!
      }.to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe "#survey_version" do
    subject { survey_submission_answer.survey_version }
    it { should eq(survey_submission_answer.survey_submission.survey_version)}
  end
  
end
