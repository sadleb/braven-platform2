require 'rails_helper'

RSpec.describe UserPolicy, type: :policy do
  let(:user) { create(:registered_user) }

  subject { described_class }

  permissions :confirm? do
    it "allows admin users" do
      user.add_role :admin
      expect(subject).to permit(user)
    end

    it "disallows non-admin users" do
      expect(subject).not_to permit(user)
    end
  end

  permissions :register? do
    it "allows admin users" do
      user.add_role :admin
      expect(subject).to permit(user)
    end

    it "disallows non-admin users" do
      expect(subject).not_to permit(user)
    end
  end

  shared_examples 'admin or CanSendNewSignupEmail policy' do
    it 'allows admin users' do
      user.add_role RoleConstants::ADMIN
      user.remove_role RoleConstants::CAN_SEND_NEW_SIGNUP_EMAIL
      expect(subject).to permit(user)
    end

    it 'allows users with CanSendNewSignupEmail role' do
      user.add_role RoleConstants::CAN_SEND_NEW_SIGNUP_EMAIL
      user.remove_role RoleConstants::ADMIN
      expect(subject).to permit(user)
    end

    it 'disallows users with neither role' do
      user.remove_role RoleConstants::ADMIN
      user.remove_role RoleConstants::CAN_SEND_NEW_SIGNUP_EMAIL
      expect(subject).not_to permit(user)
    end

    it 'allows users with both admin and CanSendNewSignupEmail role' do
      user.add_role RoleConstants::ADMIN
      user.add_role RoleConstants::CAN_SEND_NEW_SIGNUP_EMAIL
      expect(subject).to permit(user)
    end
  end

  permissions :show_send_signup_email? do
    it_behaves_like 'admin or CanSendNewSignupEmail policy'
  end

  permissions :send_signup_email? do
    it_behaves_like 'admin or CanSendNewSignupEmail policy'
  end
end
