require 'rails_helper'

RSpec.describe UserPolicy, type: :policy do
  let(:user) { create(:registered_user) }

  subject { described_class }

  shared_examples 'admin or CanSendAccountCreationEmails policy' do
    it 'allows admin users' do
      user.add_role RoleConstants::ADMIN
      user.remove_role RoleConstants::CAN_SEND_ACCOUNT_CREATION_EMAILS
      expect(subject).to permit(user)
    end

    it 'allows users with CanSendAccountCreationEmails role' do
      user.add_role RoleConstants::CAN_SEND_ACCOUNT_CREATION_EMAILS
      user.remove_role RoleConstants::ADMIN
      expect(subject).to permit(user)
    end

    it 'disallows users with neither role' do
      user.remove_role RoleConstants::ADMIN
      user.remove_role RoleConstants::CAN_SEND_ACCOUNT_CREATION_EMAILS
      expect(subject).not_to permit(user)
    end

    it 'allows users with both admin and CanSendAccountCreationEmails role' do
      user.add_role RoleConstants::ADMIN
      user.add_role RoleConstants::CAN_SEND_ACCOUNT_CREATION_EMAILS
      expect(subject).to permit(user)
    end
  end

  permissions :show_send_signup_email? do
    it_behaves_like 'admin or CanSendAccountCreationEmails policy'
  end

  permissions :send_signup_email? do
    it_behaves_like 'admin or CanSendAccountCreationEmails policy'
  end
end
