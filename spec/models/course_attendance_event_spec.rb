require 'rails_helper'
require 'canvas_api'

RSpec.describe CourseAttendanceEvent, type: :model do
  # Associations
  it { should belong_to :course }
  it { should belong_to :attendance_event }

  # Validations
  it { should validate_presence_of :course }
  it { should validate_presence_of :attendance_event }
  it { should validate_presence_of :canvas_assignment_id }

  let(:course) { create :course }
  let(:attendance_event) { create :attendance_event }
  let(:course_attendance_event) { build(
    :course_attendance_event,
    course: course,
    attendance_event: attendance_event,
  ) }

  describe '#save' do
    it 'allows saving' do
      expect { course_attendance_event.save! }.to_not raise_error
    end
  end

  describe '#canvas_url' do
    subject { course_attendance_event.canvas_url }
    it { should include course.canvas_course_id.to_s }
    it { should include course_attendance_event.canvas_assignment_id.to_s }
  end

end
