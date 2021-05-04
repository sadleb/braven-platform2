class UserPolicy < ApplicationPolicy
  def confirm?
    update?
  end

  def register?
    update?
  end

  def show_send_signup_email?
    user.can_send_new_signup_email?
  end

  def send_signup_email?
    user.can_send_new_signup_email?
  end
end
