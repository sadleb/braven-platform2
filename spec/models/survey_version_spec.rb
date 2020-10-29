require 'rails_helper'

RSpec.describe SurveyVersion, type: :model do
  
  describe '#valid?' do
    let(:survey_version) { build(:survey_version) } 

    context 'when valid' do
      it 'allows saving' do
        expect { survey_version.save! }.to_not raise_error
      end
    end
  end
end
