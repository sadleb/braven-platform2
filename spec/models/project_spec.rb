require 'rails_helper'

RSpec.describe Project, type: :model do
  
  describe '#valid?' do
    let(:project) { build(:project) } 

    context 'when valid' do
      it 'allows saving' do
        expect { project.save! }.to_not raise_error
      end
    end

    context 'when name is empty' do
      it 'disallows saving' do
        project.name = nil
        expect { project.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when points_possible is empty' do
      it 'disallows saving' do
        project.points_possible = nil
        expect { project.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when percent_of_grade_category is empty' do
      it 'disallows saving' do
        project.percent_of_grade_category = nil
        expect { project.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when percent_of_grade_category less than 0' do
      it 'disallows saving' do
        project.percent_of_grade_category = -0.5
        expect { project.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when no associated grade_category' do
      it 'disallows saving' do
        project.grade_category = nil
        expect { project.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

  end
end
