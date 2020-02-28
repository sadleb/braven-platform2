require 'rails_helper'

RSpec.describe Lesson, type: :model do
  
  describe '#valid?' do
    let(:lesson) { build(:lesson) } 

    context 'when valid' do
      it 'allows saving' do
        expect { lesson.save! }.to_not raise_error
      end
    end

    context 'when name is empty' do
      it 'disallows saving' do
        lesson.name = nil
        expect { lesson.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when points_possible is empty' do
      it 'disallows saving' do
        lesson.points_possible = nil
        expect { lesson.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when percent_of_grade_category is empty' do
      it 'disallows saving' do
        lesson.percent_of_grade_category = nil
        expect { lesson.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    # TODO: b/n 0 and 1

    context 'when no associated grade_category' do
      it 'disallows saving' do
        lesson.grade_category = nil
        expect { lesson.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

  end
end
