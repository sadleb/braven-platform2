require 'rails_helper'

RSpec.describe LrsXapiMockPolicy, type: :policy do
  let(:user) { create(:registered_user) }

  subject { described_class }

  permissions :xAPI? do
    it "allows all logged-in users" do
      expect(subject).to permit(user)
    end

    it "disallows anonymous users" do
      expect(subject).not_to permit(nil)
    end
  end
end
