class SalesforceAuthorizationPolicy < ApplicationPolicy

  def init_sync_salesforce_program?
    user.can_sync_from_salesforce?
  end

  def sync_salesforce_program?
    user.can_sync_from_salesforce?
  end

end
