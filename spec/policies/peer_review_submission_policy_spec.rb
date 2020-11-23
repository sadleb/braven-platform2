require 'rails_helper'

RSpec.describe PeerReviewSubmissionPolicy, type: :policy do
  let(:peer_review_submission) { create(:peer_review_submission) }
  let(:section) { create(:section, course: peer_review_submission.course) }
  let(:user) { create(:registered_user, section: section) }

  subject { described_class }

  describe "initialize" do
    it "disallows users that aren't logged in" do
      expect {
        subject.new(nil, peer_review_submission)
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  permissions :show? do
    it "allows admins" do
      user.add_role :admin
      expect(subject).to permit(user, peer_review_submission)
    end

    it "disallows users from viewing other peoples submissions" do
      expect(subject).not_to permit(user, peer_review_submission)
    end

    it "allows users to view their own submissions" do
      peer_review_submission.update!(user: user)
      expect(subject).to permit(user, peer_review_submission)
    end
  end

  permissions :create? do
    it "allows admins" do
      user.add_role :admin
      expect(subject).to permit(user, peer_review_submission)
    end

    it "allows students who are enrolled in the course" do
      peer_review_submission.update!(user: user)
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit(user, peer_review_submission)
    end

    it "disallows users who aren't in the course" do
      expect(subject).not_to permit(user, peer_review_submission)
    end
  end

  permissions :new? do
    it "allows admins" do
      user.add_role :admin
      expect(subject).to permit(user, peer_review_submission)
    end

    it "allows students who are enrolled in the course" do
      peer_review_submission.update!(user: user)
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit(user, peer_review_submission)
    end

    it "disallows users who aren't in the course" do
      expect(subject).not_to permit(user, peer_review_submission)
    end
  end
end
