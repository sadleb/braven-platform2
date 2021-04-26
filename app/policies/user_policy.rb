class UserPolicy < ApplicationPolicy
  def confirm?
    update?
  end

  def register?
    update?
  end

  def show_send_sign_up_email?
    user.can_send_new_sign_up_email?
  end

  def send_sign_up_email?
    user.can_send_new_sign_up_email?
  end
end
