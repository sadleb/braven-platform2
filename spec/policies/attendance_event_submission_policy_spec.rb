require 'rails_helper'

RSpec.describe AttendanceEventSubmissionPolicy, type: :policy do
  subject { described_class }

  let(:course) { create :course }
  let(:section) { create :section, course: course }

  let(:course_attendance_event) { create :course_attendance_event, course: course }

  let(:ta_user) { create :ta_user, section: section }
  let(:attendance_event_submission) { create(
    :attendance_event_submission,
    course_attendance_event: course_attendance_event,
    user: ta_user,
  ) }

  let(:user) { create :registered_user }

  shared_examples 'TA-only policy' do
    scenario 'allows admin users' do
      user.add_role :admin
      expect(subject).to permit(user, record)
    end

    scenario 'allows TA users' do
      user.add_role RoleConstants::TA_ENROLLMENT, section
      expect(subject).to permit(user, record)
    end

    scenario 'disallows Fellow users' do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect {
        expect(subject).not_to permit(user, record)
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    scenario 'disallows non-enrolled users' do
      expect {
        expect(subject).not_to permit(user, record)
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  permissions :launch? do
    context 'course attendance event exists' do
      let(:record) { attendance_event_submission }
      it_behaves_like 'TA-only policy'
    end

    context 'no attendance events for course' do
      let(:record) { course }
      it_behaves_like 'TA-only policy'
    end
  end

  permissions :edit? do
    let(:record) { attendance_event_submission }
    it_behaves_like 'TA-only policy'
  end

  permissions :update? do
    let(:record) { attendance_event_submission }
    it_behaves_like 'TA-only policy'
  end
end
