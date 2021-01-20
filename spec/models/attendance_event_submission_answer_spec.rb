require 'rails_helper'

RSpec.describe AttendanceEventSubmissionAnswer, type: :model do

  # Associations
  it { should belong_to :attendance_event_submission }
  it { should belong_to :for_user }

  let(:course) { create :course }
  let(:section) { create :section, course: course }

  let(:fellow_user) { create :fellow_user, section: section }
  let(:ta_user) { create :ta_user, section: section }

  let(:attendance_event) { create :attendance_event }
  let(:course_attendance_event) { create(
    :course_attendance_event,
    course: course,
    attendance_event: attendance_event,
  ) }

  let(:attendance_event_submission) { create(
    :attendance_event_submission,
    course_attendance_event: course_attendance_event,
    user: ta_user,
  ) }
  let(:attendance_event_submission_answer) { build(
    :attendance_event_submission_answer,
    attendance_event_submission: attendance_event_submission,
    for_user: fellow_user,
  ) }

  describe "#save" do
    it 'allows saving' do
      expect { attendance_event_submission_answer.save! }.to_not raise_error
    end
  end

  describe '#user' do
    subject { attendance_event_submission_answer.user }
    it { should eq(ta_user) }
  end

  describe '#for_user' do
    subject { attendance_event_submission_answer.for_user }
    it { should eq(fellow_user) }
  end

  describe '#submission' do
    subject { attendance_event_submission_answer.submission }
    it { should eq(attendance_event_submission) }
  end
end
