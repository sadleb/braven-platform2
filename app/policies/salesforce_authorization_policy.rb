class SalesforceAuthorizationPolicy < ApplicationPolicy

  def init_sync_from_salesforce_program?
    user.can_sync_from_salesforce?
  end

  def confirm_send_signup_emails?
    user.can_sync_from_salesforce? && user.can_send_account_creation_emails?
  end

  def sync_from_salesforce_program?
    user.can_sync_from_salesforce?
  end

  def update_contacts?
    user.can_sync_from_salesforce?
  end
end
