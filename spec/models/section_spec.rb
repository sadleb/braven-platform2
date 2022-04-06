require 'rails_helper'

RSpec.describe Section, type: :model do

  describe '#save' do
    let(:course) { create :course }
    let(:section) { build(:section, course: course) }

    context 'when name has extra whitespace' do
      it 'strips away whitespace in the name' do
        orig_name = section.name
        section.name = " #{section.name} "
        section.save!
        expect(section.name).to eq(orig_name)
      end
    end
  end
end
