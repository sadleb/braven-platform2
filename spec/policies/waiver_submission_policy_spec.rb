require 'rails_helper'

RSpec.describe WaiverSubmissionPolicy, type: :policy do
  let(:user) { create(:registered_user) }
  let(:course) { create(:course) }
  let(:section) { create(:section, course: course) }

  subject { described_class }

  permissions :launch? do
    it "allows users with StudentEnrollment role to launch waivers" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit(user, course)
    end

    it "disallows users who do not have StudentEnrollment role to launch waivers" do
      user.add_role RoleConstants::TA_ENROLLMENT, section
      expect {
        expect(subject).not_to permit(user, course)
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end
end