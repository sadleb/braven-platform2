require 'rails_helper'

RSpec.describe DiscordSignupPolicy, type: :policy do
  let(:user) { create(:registered_user) }
  let(:course) { create(:course) }
  let(:section) { create(:section, course: course) }

  subject { described_class }

  permissions :launch? do
    it "allows enrolled users" do
      user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      expect(subject).to permit(user, course)
    end

    it "disallows non-enrolled users" do
      expect(subject).not_to permit(user, course)
    end

    it "disallows anonymous users" do
      expect(subject).not_to permit(nil, course)
    end
  end

  permissions :oauth? do
    it "allows registered users" do
      expect(subject).to permit(user)
    end

    it "disallows anonymous users" do
      expect(subject).not_to permit(nil)
    end
  end

  permissions :completed? do
    it "allows registered users" do
      expect(subject).to permit(user)
    end

    it "disallows anonymous users" do
      expect(subject).not_to permit(nil)
    end
  end

  permissions :publish? do
    it "allows admin users" do
      user.add_role :admin
      expect(subject).to permit(user)
    end

    it "disallows non-admin users" do
      expect(subject).not_to permit(user)
    end
  end

  permissions :unpublish? do
    it "allows admin users" do
      user.add_role :admin
      expect(subject).to permit(user)
    end

    it "disallows non-admin users" do
      expect(subject).not_to permit(user)
    end
  end
end
