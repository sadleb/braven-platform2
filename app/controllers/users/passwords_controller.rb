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
    reset_password_token = params[:reset_password_token]

    # Don't allow nil tokens. (This would be a password reset bypass.)
    return super unless reset_password_token

    user = User.with_reset_password_token(reset_password_token)
    add_honeycomb_context(user)

    if user.present? && !user.registered?
      # Since we've verified the token, and we know the user has not done
      # the sign_up flow yet, redirect to RegistrationsController#new to set
      # their initial password, create their Canvas account, etc instead.
      # Note the reset_password_token may be expired at this point, but
      # we don't care; that will be validated in RegisterUserAccount.
      return redirect_to new_user_registration_path(reset_password_token: reset_password_token)
    end

    super
  end

  # PUT /resource/password
  def update
    # https://www.rubydoc.info/github/plataformatec/devise/Devise/PasswordsController#update-instance_method
    super do
      add_honeycomb_context(resource)
      if resource.errors.any? { |e| e.attribute == :reset_password_token }
        # If the validation fails on token, whether because the token
        # didn't match any users, or was expired, redirect to the #new
        # page with a message explaining the token was invalid and the form
        # to send a new reset email. Do not reveal what account this token
        # may have been tied to, or the exact reason for the token failure.
        return redirect_to new_user_password_path(resend: true)
      end

      if resource.errors.empty?
        # Invalidate signup tokens when the password is reset.
        # The reset tokens are already removed in `super`.
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

private

  def add_honeycomb_context(user)
    Honeycomb.add_field('user.present?', user.present?)
    user&.add_to_honeycomb_trace()
  end
end
