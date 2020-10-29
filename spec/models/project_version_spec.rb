require 'rails_helper'

RSpec.describe ProjectVersion, type: :model do
  
  describe '#valid?' do
    let(:project_version) { build(:project_version) } 

    context 'when valid' do
      it 'allows saving' do
        expect { project_version.save! }.to_not raise_error
      end
    end
  end
end
