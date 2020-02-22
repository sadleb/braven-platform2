require 'rails_helper'

RSpec.describe Logistic, type: :model do
  
  describe '#save' do
    let(:logistic) { build(:logistic) }

    context 'when day of week has extra whitespace' do
      it 'strips away whitespace in the name' do
        orig_day = logistic.day_of_week
        logistic.day_of_week = " #{logistic.day_of_week} "
        logistic.save!
        expect(logistic.day_of_week).to eq(orig_day)
      end
    end

    context 'when day_of_week is not actually a day of the week' do
      it 'is not valid' do
        logistic.day_of_week = 'February'
        expect(logistic).to_not be_valid
      end
    end
  end
end
