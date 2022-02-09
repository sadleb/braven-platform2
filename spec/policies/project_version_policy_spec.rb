require 'rails_helper'

RSpec.describe ProjectVersionPolicy, type: :policy do
  let(:user) { create(:registered_user) }
  let(:course) { create(:course) }
  let(:project) { create(:project) }
  let(:project_version) { create(:project_version, project: project) }
  let(:section) { create(:section, course_id: course.id) }
  let(:course_project_version) { create(:course_project_version, course: course, project_version: project_version) }

  subject { described_class }

  permissions :show? do
    it "allows any admin user to show a given project version" do
      user.add_role :admin
      expect(subject).to permit user, project_version
    end

    it "allows a non-admin user to show a project version attached to a course where this user is enrolled" do
      course_project_version
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit user, project_version
    end

    it "disallows any user when no project version is passed in" do
      expect {
        expect(subject).not_to permit user
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "disallows non-admin users not enrolled in a course attached to the project version" do
      expect {
        expect(subject).not_to permit user, project_version
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end
end
