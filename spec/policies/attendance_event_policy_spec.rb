require 'rails_helper'

RSpec.describe AttendanceEventPolicy, type: :policy do
  let(:user) { create(:registered_user) }

  subject { described_class }

  shared_examples 'admin-only policy' do
    scenario 'allows admin users' do
      user.add_role :admin
      expect(subject).to permit(user)
    end

    scenario 'disallows non-admin users' do
      expect(subject).not_to permit(user)
    end
  end

  permissions :index? do
    it_behaves_like 'admin-only policy'
  end

  permissions :new? do
    it_behaves_like 'admin-only policy'
  end

  permissions :create? do
    it_behaves_like 'admin-only policy'
  end

  permissions :destroy? do
    it_behaves_like 'admin-only policy'
  end
end
