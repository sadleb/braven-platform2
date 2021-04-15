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

    # From https://www.rubydoc.info/github/plataformatec/devise/Devise/Models/Recoverable/ClassMethods#reset_password_by_token-instance_method
    original_token = params[:reset_password_token]
    reset_password_token = Devise.token_generator.digest(User, :reset_password_token, original_token)

    user = User.find_by(reset_password_token: reset_password_token)
    if user.present? && !user.registered?
      # Since we've verified the token, and we know the user has not done
      # the sign_up flow yet, redirect them there to set their initial
      # password, create their Canvas account, etc instead.
      # TODO: Redirect by a token instead of SF ID.
      # https://app.asana.com/0/1174274412967132/1200147504835146/f
      return redirect_to new_user_registration_path(u: user.salesforce_id)
    else
      super
    end
  end

  # PUT /resource/password
  # def update
  #   super
  # end

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
