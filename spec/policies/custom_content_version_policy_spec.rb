require 'rails_helper'

RSpec.describe CustomContentVersionPolicy, type: :policy do
  let(:admin_user) { create(:admin_user) }
  let(:user) { create(:registered_user) }

  subject { described_class }

  permissions :show? do
    it "allows all admin users" do
      expect(subject).to permit(admin_user)
    end

    it "disallows random registered users" do
      expect(subject).not_to permit(user)
    end

    it "disallows anonymous users" do
      expect(subject).not_to permit(nil)
    end
  end
end
