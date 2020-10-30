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
end
