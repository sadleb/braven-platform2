require 'rails_helper'

RSpec.describe SalesforceAuthorizationPolicy, type: :policy do
  let(:user) { create(:registered_user) }

  subject { described_class }

  shared_examples 'admin or CanSyncFromSalesforce policy' do
   it 'allows admin users' do
      user.add_role RoleConstants::ADMIN
      user.remove_role RoleConstants::CAN_SYNC_FROM_SALESFORCE
      expect(subject).to permit(user)
    end

    it 'allows users with CanSyncFromSalesforce role' do
      user.add_role RoleConstants::CAN_SYNC_FROM_SALESFORCE
      user.remove_role RoleConstants::ADMIN
      expect(subject).to permit(user)
    end

    it 'disallows users with neither role' do
      user.remove_role RoleConstants::ADMIN
      user.remove_role RoleConstants::CAN_SYNC_FROM_SALESFORCE
      expect(subject).not_to permit(user)
    end

    it 'allows users with both admin and CanSyncFromSalesforce role' do
      user.add_role RoleConstants::ADMIN
      user.add_role RoleConstants::CAN_SYNC_FROM_SALESFORCE
      expect(subject).to permit(user)
    end
  end

  permissions :init_sync_salesforce_program? do
    it_behaves_like 'admin or CanSyncFromSalesforce policy'
  end

  permissions :sync_salesforce_program? do
    it_behaves_like 'admin or CanSyncFromSalesforce policy'
  end

  permissions :update_contacts? do
    it_behaves_like 'admin or CanSyncFromSalesforce policy'
  end

end
