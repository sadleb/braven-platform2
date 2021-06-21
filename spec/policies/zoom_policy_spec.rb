require 'rails_helper'

RSpec.describe ZoomPolicy, type: :policy do
  let(:user) { create(:registered_user) }

  subject { described_class }

  shared_examples 'admin policy' do
    it "allows admin users" do
      user.add_role :admin
      expect(subject).to permit(user)
    end

    it "disallows non-admin users" do
      expect(subject).not_to permit(user)
    end
  end

  permissions :init_generate_zoom_links? do
    it_behaves_like 'admin policy'
  end

  permissions :generate_zoom_links? do
    it_behaves_like 'admin policy'
  end
end
