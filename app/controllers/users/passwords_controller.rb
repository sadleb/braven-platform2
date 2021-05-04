# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  layout 'accounts'

  # GET /resource/password/new
  # def new
  #   super
  # end

  # POST /resource/password
  # def create
  #   super
  # end

  # GET /resource/password/edit?reset_password_token=abcdef
  def edit
    # Don't allow nil tokens. (This would be a password reset bypass.)
    return super unless params[:reset_password_token]

    user = User.with_reset_password_token(reset_password_token)
    if user.present? && !user.registered?
      # Since we've verified the token, and we know the user has not done
      # the sign_up flow yet, redirect to RegistrationsController#new to set
      # their initial password, create their Canvas account, etc instead.
      return redirect_to user_registration_path(reset_password_token: reset_password_token)
    end

    super
  end

  # PUT /resource/password
  def update
    # Invalidate signup tokens when the password is reset.
    # https://www.rubydoc.info/github/plataformatec/devise/Devise/PasswordsController#update-instance_method
    super do
      if resource.errors.empty?
        resource.update(
          signup_token: nil,
          signup_token_sent_at: nil,
        )
      end
    end
  end

  # protected

  def after_resetting_password_path_for(resource)
     login_url = cas_login_url
     login_url += (URI.parse(cas_login_url).query ? '&' : '?')
     login_url += "notice=Password reset successfully.".freeze
     login_url
  end

  # The path used after sending reset password instructions
  def after_sending_reset_password_instructions_path_for(_)
    users_password_check_email_path
  end

end
