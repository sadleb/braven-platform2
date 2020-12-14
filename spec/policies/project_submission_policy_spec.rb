require 'rails_helper'

RSpec.describe ProjectSubmissionPolicy, type: :policy do
  let(:user) { create(:registered_user) }
  let(:course) { create(:course) }
  let(:project_version) { create(:project_version) }
  let(:section) { create(:section, course: course) }
  let(:course_project_version) { create(:course_project_version, course: course, custom_content_version: project_version) }
  let(:project_submission) { create(:project_submission, user: user, course_project_version: course_project_version) }

  subject { described_class }

  permissions :show? do
    it "allows any admin user to show a given project submission" do
      user.add_role :admin
      expect(subject).to permit user, project_submission
    end

    it "allows a ta user to show a project submission from one of their students" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      ta_user = create(:registered_user)
      ta_user.add_role RoleConstants::TA_ENROLLMENT, section
      expect(subject).to permit ta_user, project_submission
    end

    it "allows users to see their own submissions" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit user, project_submission
    end

    it "disallows users to see submissions from another student in their section" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      peer_user = create(:registered_user)
      peer_user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).not_to permit peer_user, project_submission
    end

    it "disallows non-admin users not enrolled in a course attached to the project" do
      expect(subject).not_to permit user, project_submission
    end
  end

  permissions :new? do
    it "allows any admin user to show a given project submission" do
      user.add_role :admin
      expect(subject).to permit user, project_submission
    end

    it "allows a non-admin user to show a project submission attached to a course where this user is enrolled" do
      course_project_version
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit user, project_submission
    end

    it "disallows non-admin users not enrolled in a course attached to the project" do
      expect(subject).not_to permit user, project_submission
    end
  end

  permissions :create? do
    it "allows users to create their own project submissions attached to a course where this user is enrolled" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit user, project_submission
    end

    it "disallows users to create someone else's project submissions attached to a course where both users are enrolled" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      peer_user = create(:registered_user)
      peer_user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).not_to permit peer_user, project_submission
    end
  end

  permissions :update? do
    it "allows users to create their own project submissions attached to a course where this user is enrolled" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit user, project_submission
    end

    it "disallows users to create someone else's project submissions attached to a course where both users are enrolled" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      peer_user = create(:registered_user)
      peer_user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).not_to permit peer_user, project_submission
    end
  end

  permissions :edit? do
    it "allows users to create their own project submissions attached to a course where this user is enrolled" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit user, project_submission
    end

    it "disallows users to create someone else's project submissions attached to a course where both users are enrolled" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      peer_user = create(:registered_user)
      peer_user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).not_to permit peer_user, project_submission
    end
  end
end
