require 'rails_helper'

RSpec.describe LessonSubmission, type: :model do
  
  describe '#valid?' do
    let(:lesson_submission) { build(:lesson_submission) } 

    context 'when valid' do
      it 'allows saving' do
        expect { lesson_submission.save! }.to_not raise_error
      end
    end

    context 'when no associated user' do
      it 'disallows saving' do
        lesson_submission.user = nil
        expect { lesson_submission.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when no associated lesson' do
      it 'disallows saving' do
        lesson_submission.lesson = nil
        expect { lesson_submission.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

  end
end
