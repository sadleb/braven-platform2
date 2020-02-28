require 'rails_helper'

RSpec.describe Organization, type: :model do
  
  describe '#save' do
    let(:org) { build(:organization, name: org_name) }

    context 'when name has extra whitespace' do
      let(:org_name) { ' Organization ' }

      it 'strips away whitespace in the name' do
        org.save!
        expect(org.name).to eq('Organization')
      end
    end

    context 'when name is empty' do
      let(:org_name) { '' }
      it 'disallows saving' do
        expect { org.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
