require 'rails_helper'

RSpec.describe CourseAttendanceEventPolicy, type: :policy do
  let(:course) { create :course }
  let(:section) { create :section, course: course }
  let(:course_attendance_event) { create :course_attendance_event, course: course }
  let(:user) { create :registered_user }

  subject { described_class }

  shared_examples 'admin-only policy' do
    scenario 'allows admin users' do
      user.add_role :admin
      expect(subject).to permit(user)
    end

    scenario 'disallows non-admin users' do
      expect(subject).not_to permit(user)
    end
  end

  permissions :publish? do
    it_behaves_like 'admin-only policy'
  end

  permissions :unpublish? do
    it_behaves_like 'admin-only policy'
  end

  permissions :launch? do
    it 'allows admin users' do
      user.add_role :admin
      expect(subject).to permit(user, course_attendance_event)
    end

    it 'allows enrolled (Fellow) users' do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit(user, course_attendance_event)
    end

    it 'allows enrolled (TA) users' do
      user.add_role RoleConstants::TA_ENROLLMENT, section
      expect(subject).to permit(user, course_attendance_event)
    end

    it 'disallows non-enrolled users' do
      expect(subject).not_to permit(user, course_attendance_event)
    end
  end
end
