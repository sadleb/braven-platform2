require 'rails_helper'

RSpec.describe FellowEvaluationSubmissionPolicy, type: :policy do
  let(:course) { create :course_launched }
  let(:section) { create :section, course: course }
  let(:user) { create :registered_user }
  let(:fellow_evaluation_submission) { build(
    :fellow_evaluation_submission,
    course: course,
  ) }
  subject { described_class }

  describe "initialize" do

    it "disallows users that aren't logged in" do
      expect {
        subject.new(nil, fellow_evaluation_submission)
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  permissions :new? do
    it "allows admins" do
      user.add_role :admin
      expect(subject).to permit(user, fellow_evaluation_submission)
    end

    it "allows TAs" do
      user.add_role RoleConstants::TA_ENROLLMENT, section
      expect(subject).to permit(user, fellow_evaluation_submission)
    end

    it "allows students who are enrolled in the course" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit(user, fellow_evaluation_submission)
    end

    it "disallows users who aren't in the course" do
      expect(subject).not_to permit(user, fellow_evaluation_submission)
    end
  end

  permissions :create? do
    it "allows students who are enrolled in the course" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit(user, fellow_evaluation_submission)
    end

    it 'disallows non-students (admins)' do
      user.add_role :admin
      expect(subject).not_to permit(user, fellow_evaluation_submission)
    end

    it 'disallows non-students (TAs)' do
      user.add_role RoleConstants::TA_ENROLLMENT, section
      expect(subject).not_to permit(user, fellow_evaluation_submission)
    end

    it 'diallows non-students (non-enrolled)' do
      expect(subject).not_to permit(user, fellow_evaluation_submission)
    end
  end

  permissions :show? do
    let(:admin_user) { create :admin_user }
    let(:ta_user) { create :ta_user, section: section }
    before(:each) do
      fellow_evaluation_submission.update!(user: user)
    end

    it "allows users to view their own submissions" do
      expect(subject).to permit(user, fellow_evaluation_submission)
    end

    it "allows admins to see a student's sumbmission" do
      expect(subject).to permit(admin_user, fellow_evaluation_submission)
    end

    it "disallows users from viewing other peoples submissions" do
      expect(subject).not_to permit(ta_user, fellow_evaluation_submission)
    end
  end
end
