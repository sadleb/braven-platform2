require 'rails_helper'

RSpec.describe AttendanceEvent, type: :model do
  # Validations
  it { should validate_presence_of :title }

  let(:attendance_event) { build :attendance_event }

  describe '#save' do
    it 'allows saving' do
      expect { attendance_event.save! }.to_not raise_error
    end

    it 'disallows saving without a title' do
      attendance_event.title = ''
      expect { attendance_event.save! }.to raise_error ActiveRecord::RecordInvalid
    end
  end
end
