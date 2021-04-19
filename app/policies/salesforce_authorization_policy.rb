class SalesforceAuthorizationPolicy < ApplicationPolicy

  def init_sync_to_lms?
    index?
  end

  def sync_to_lms?
    update?
  end

  # This action is not behind a login, so we don't have access to @user.
  # It's hit with an access_token to authenticate, so just return `true`
  # and if it's authenticated this action is authorized.
  def update_contacts?
    true
  end
end
