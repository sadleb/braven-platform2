class SalesforceAuthorizationPolicy < ApplicationPolicy

  def init_sync_from_salesforce_program?
    user.can_sync_from_salesforce?
  end

  def confirm_send_sign_up_emails?
    user.can_sync_from_salesforce? && user.can_send_new_sign_up_email?
  end

  def sync_from_salesforce_program?
    user.can_sync_from_salesforce?
  end

  def update_contacts?
    user.can_sync_from_salesforce?
  end
end
