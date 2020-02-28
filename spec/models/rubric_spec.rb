require 'rails_helper'

RSpec.describe Rubric, type: :model do
  
  describe '#valid?' do
    let(:rubric) { build(:rubric) } 

    context 'when valid' do
      it 'allows saving' do
        expect { rubric.save! }.to_not raise_error
      end
    end

    context 'when points_possible is empty' do
      it 'disallows saving' do
        rubric.points_possible = nil
        expect { rubric.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when no associated project' do
      it 'disallows saving' do
        rubric.project = nil
        expect { rubric.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
