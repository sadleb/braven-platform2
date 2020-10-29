require 'rails_helper'

RSpec.describe Survey, type: :model do
  
  describe '#valid?' do
    let(:survey) { build(:survey) } 

    context 'when valid' do
      it 'allows saving' do
        expect { survey.save! }.to_not raise_error
      end
    end
  end
end
