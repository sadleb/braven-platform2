class SalesforceAuthorizationPolicy < ApplicationPolicy

  def init_sync_from_salesforce_program?
    user.can_sync_from_salesforce?
  end

  def sync_from_salesforce_program?
    user.can_sync_from_salesforce?
  end

  def update_contacts?
    user.can_sync_from_salesforce?
  end
end
