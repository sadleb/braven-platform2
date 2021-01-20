require 'rails_helper'

RSpec.describe AttendanceEventSubmission, type: :model do
  # Associations
  it { should belong_to :user }
  it { should belong_to :course_attendance_event }

  # Validations
  it { should validate_presence_of :user }
  it { should validate_presence_of :course_attendance_event }

  let(:course) { create :course }

  let(:attendance_event) { create :attendance_event }
  let(:course_attendance_event) { create(
    :course_attendance_event,
    course: course,
    attendance_event: attendance_event,
  ) }

  let(:section) { create :section, course: course }
  let(:user) { create :ta_user, section: section }
  
  let(:attendance_event_submission) { build(
    :attendance_event_submission,
    user: user,
    course_attendance_event: course_attendance_event,
  ) }

  describe '#save' do
    it 'allows saving' do
      expect { attendance_event_submission.save! }.to_not raise_error
    end
  end

  describe '#course' do
    subject { attendance_event_submission.course }
    it { should eq(course) }
  end

  describe '#save_answers!' do
    subject { attendance_event_submission.save_answers!(answers) }

    shared_examples 'saves the answers to the submission' do
      scenario 'should not raise error' do
        expect { subject }.not_to raise_error
      end

      scenario 'create new answers' do
        expect {
          subject
        }.to change(AttendanceEventSubmissionAnswer, :count).by(answers.count)
      end
    end

    context 'empty inputs' do
      let(:answers) { {} }
      it_behaves_like 'saves the answers to the submission'
    end

    context 'with attendance statuses' do
      let(:fellow_user_1) { create :fellow_user, section: section, canvas_user_id: 1 }
      let(:fellow_user_2) { create :fellow_user, section: section, canvas_user_id: 2 }
      let(:fellow_user_3) { create :fellow_user, section: section, canvas_user_id: 3 }
      let(:fellow_user_4) { create :fellow_user, section: section, canvas_user_id: 4 }
      let(:answers) { {
        fellow_user_1.id => { in_attendance: false, late: nil, absence_reason: 'My reason for being absent' },
        fellow_user_2.id => { in_attendance: true, late: false, absence_reason: nil },
        fellow_user_3.id => { in_attendance: true, late: true, absence_reason: nil },
        fellow_user_4.id => { in_attendance: nil, late: nil, absence_reason: nil },
      } }
      it_behaves_like 'saves the answers to the submission'
    end
  end
end
