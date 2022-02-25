require 'rails_helper'

RSpec.describe CapstoneEvaluationSubmissionPolicy, type: :policy do
  let(:user) { create :registered_user }
  let(:course) { create :course }
  let(:section) { create :section, course: course }
  let(:ta_section) { create :ta_section, course: course }
  let(:capstone_evaluation_submission) { create(
    :capstone_evaluation_submission,
    course: course,
  ) }

  subject { described_class }

  describe 'initialize' do
    it 'disallows users that aren\'t logged in' do
      expect {
        subject.new(nil, capstone_evaluation_submission)
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  permissions :show? do
    let(:fellow_user) { create :fellow_user, section: section }

    before(:each) do
      capstone_evaluation_submission.update!(user: fellow_user)
    end

    it 'allows users to view their own submissions' do
      expect(subject).to permit(fellow_user, capstone_evaluation_submission)
    end

    it 'allows admins' do
      user.add_role :admin
      expect(subject).to permit(user, capstone_evaluation_submission)
    end

    it 'disallows users from viewing other peoples submissions' do
      expect {
        expect(subject).not_to permit(user, capstone_evaluation_submission)
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'allows TAs to view fellow\'s submission' do
      user.add_role RoleConstants::TA_ENROLLMENT, ta_section
      expect(subject).to permit(user, capstone_evaluation_submission)
    end

    it 'allows LCs to view fellow\'s submission' do
      user.add_role RoleConstants::TA_ENROLLMENT, section
      expect(subject).to permit(user, capstone_evaluation_submission)
    end

    it 'disallows LCs from other sections' do
      another_section = create(:section, course: capstone_evaluation_submission.course)
      user.add_role RoleConstants::TA_ENROLLMENT, another_section
      expect {
        expect(subject).not_to permit(user, capstone_evaluation_submission)
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'disallows TAs from other courses' do
      another_course = create(:course)
      ta_section = create(:ta_section, course: another_course)
      user.add_role RoleConstants::TA_ENROLLMENT, ta_section
      expect {
        expect(subject).not_to permit(user, capstone_evaluation_submission)
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  permissions :create? do
    it 'allows students who are enrolled in the course' do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit(user, capstone_evaluation_submission)
    end

    it 'disallows non-students (admins)' do
      user.add_role :admin
      expect(subject).not_to permit(user, capstone_evaluation_submission)
    end

    it 'disallows non-students (TAs)' do
      user.add_role RoleConstants::TA_ENROLLMENT, ta_section
      expect(subject).not_to permit(user, capstone_evaluation_submission)
    end

    it 'disallows non-students (LCs)' do
      user.add_role RoleConstants::TA_ENROLLMENT, section
      expect(subject).not_to permit(user, capstone_evaluation_submission)
    end

    it 'disallows non-students (non-enrolled)' do
      expect(subject).not_to permit(user, capstone_evaluation_submission)
    end
  end

  permissions :new? do
    it 'allows admins' do
      user.add_role :admin
      expect(subject).to permit(user, capstone_evaluation_submission)
    end

    it 'allows TAs' do
      user.add_role RoleConstants::TA_ENROLLMENT, ta_section
      capstone_evaluation_submission.user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit(user, capstone_evaluation_submission)
    end

    it 'allows LCs' do
      user.add_role RoleConstants::TA_ENROLLMENT, section
      capstone_evaluation_submission.user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit(user, capstone_evaluation_submission)
    end

    it 'allows students who are enrolled in the course' do
      capstone_evaluation_submission.update!(user: user)
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit(user, capstone_evaluation_submission)
    end

    it 'disallows users who aren\'t in the course' do
      expect {
        expect(subject).not_to permit(user, capstone_evaluation_submission)
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  permissions :launch? do
    it 'allows admin users' do
      user.add_role :admin
      expect(subject).to permit(user, capstone_evaluation_submission)
    end

    it 'allows enrolled fellows' do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit(user, capstone_evaluation_submission)
    end

    it 'disallows users that are not fellows or admin (LCs/TAs)' do
      user.add_role RoleConstants::TA_ENROLLMENT, section
      expect {
        expect(subject).not_to permit(user, capstone_evaluation_submission)
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'disallows non-enrolled users' do
      expect {
        expect(subject).not_to permit(user, capstone_evaluation_submission)
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    it 'disallows anonymous users' do
      expect {
        expect(subject).not_to permit(user, capstone_evaluation_submission)
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  permissions :score? do
    it 'allows admin users to post scores' do
      user.add_role :admin
      expect(subject).to permit(user, capstone_evaluation_submission)
    end

    it 'disallows enrolled fellows' do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).not_to permit(user, capstone_evaluation_submission)
    end

    it 'disallows LCs/TAs users' do
      user.add_role RoleConstants::TA_ENROLLMENT, section
        expect(subject).not_to permit(user, capstone_evaluation_submission)
    end

    it 'disallows non-enrolled users' do
      expect(subject).not_to permit(user, capstone_evaluation_submission)
    end

    it 'disallows anonymous users' do
      expect {
        expect(subject).not_to permit(nil, capstone_evaluation_submission)
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end
end
