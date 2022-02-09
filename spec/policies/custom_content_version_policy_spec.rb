require 'rails_helper'

RSpec.describe CustomContentVersionPolicy, type: :policy do
  let(:admin_user) { create(:admin_user) }
  let(:user) { create(:registered_user) }
  let(:custom_content_version) { create(:custom_content_version) }

  subject { described_class }

  permissions :show? do
    it "allows all admin users" do
      expect(subject).to permit(admin_user, custom_content_version)
    end

    it "disallows random registered users" do
      expect {
        expect(subject).not_to permit(user, custom_content_version)
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "disallows anonymous users" do
      expect {
        expect(subject).not_to permit(nil, custom_content_version)
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end
end
