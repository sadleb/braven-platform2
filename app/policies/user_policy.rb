class UserPolicy < ApplicationPolicy
  def show_send_signup_email?
    user.can_send_account_creation_emails?
  end

  def send_confirm_email?
    user.can_send_account_creation_emails?
  end

  def send_signup_email?
    user.can_send_account_creation_emails?
  end
end
