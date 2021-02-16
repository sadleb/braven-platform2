require 'rails_helper'

RSpec.describe AcceleratorSurveySubmissionPolicy, type: :policy do
  let(:user) { create :registered_user }
  let(:course) { create :course }
  let(:section) { create :section, course: course }
  let(:ta_section) { create :ta_section, course: course }
  let(:accelerator_survey_submission) { build(
    :accelerator_survey_submission,
    user: user,
    course: course,
  ) }

  subject { described_class }

  permissions :completed? do
    it "allows any admin user to view the submission confirmation page" do
      user.add_role :admin
      expect(subject).to permit user, accelerator_survey_submission
    end

    it "allows a ta user to view a submission confirmations" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      ta_user = create(:registered_user)
      ta_user.add_role RoleConstants::TA_ENROLLMENT, ta_section
      expect(subject).to permit ta_user, accelerator_survey_submission
    end

    it "allows an lc user to view a submission confirmation for one of their students" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      lc_user = create(:registered_user)
      lc_user.add_role RoleConstants::TA_ENROLLMENT, section
      expect(subject).to permit lc_user, accelerator_survey_submission
    end

    it "allows users to see their own submission confirmation" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit user, accelerator_survey_submission
    end

    it "disallows users to see submissions from another student in their section" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      peer_user = create(:registered_user)
      peer_user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).not_to permit peer_user, accelerator_survey_submission
    end

    it "disallows a ta from another course" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      another_course = create(:course)
      ta_section = create(:ta_section, course: another_course)
      ta_user = create(:registered_user)
      ta_user.add_role RoleConstants::TA_ENROLLMENT, ta_section
      expect(subject).not_to permit ta_user, accelerator_survey_submission
    end

    it "disallows lc for another cohort" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      another_section = create(:section, course: course)
      lc_user = create(:registered_user)
      lc_user.add_role RoleConstants::TA_ENROLLMENT, another_section
      expect(subject).not_to permit lc_user, accelerator_survey_submission
    end

    it "disallows non-admin users not enrolled in a course attached to the project" do
      expect(subject).not_to permit user, accelerator_survey_submission
    end
  end

  permissions :new? do
    it "allows any admin user to see the accelerator survey form" do
      user.add_role :admin
      expect(subject).to permit user, accelerator_survey_submission
    end

    it "allows any fellow enrolled in course to see the accelerator survey form" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit user, accelerator_survey_submission
    end

    it "allows any TA enrolled in course to see the accelerator survey form" do
      user.add_role RoleConstants::TA_ENROLLMENT, section
      expect(subject).to permit user, accelerator_survey_submission
    end

    it "disallows non-admin users not enrolled in a course attached to the project" do
      expect(subject).not_to permit user, accelerator_survey_submission
    end
  end

  permissions :launch? do
    it "allows any admin user to see the accelerator survey launch button" do
      user.add_role :admin
      expect(subject).to permit user, accelerator_survey_submission
    end

    it "allows any fellow enrolled in course to see the accelerator survey launch button" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit user, accelerator_survey_submission
    end

    it "allows any TA enrolled in course to see the accelerator survey launch button" do
      user.add_role RoleConstants::TA_ENROLLMENT, section
      expect(subject).to permit user, accelerator_survey_submission
    end

    it "disallows non-admin users not enrolled in course to see the accelerator survey launch button" do
      expect(subject).not_to permit user, accelerator_survey_submission
    end
  end

  permissions :create? do
    it "allow a fellow enrolled in course to submit" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit user, accelerator_survey_submission
    end

    it "disallows non-fellow (admin) from submitting" do
      user.add_role :admin
      expect(subject).not_to permit user, accelerator_survey_submission
    end

    it "disallows non-fellow (ta) from submitting" do
      user.add_role RoleConstants::TA_ENROLLMENT, section
      expect(subject).not_to permit user, accelerator_survey_submission
    end

    it "disallows non-enrolled user from submitting" do
      # Note: we don't do add_role here, so the user isn't enrolled
      expect(subject).not_to permit user, accelerator_survey_submission
    end
  end
end
