# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  layout 'accounts'
  before_action :configure_sign_up_params, only: [:create]
  # before_action :configure_account_update_params, only: [:update]
  before_action :set_tokens, only: [:new, :create]

  # GET /resource
  def show
    # Show the thank you for registering page.
    # NOTE: Do NOT set self.resource in this action, or otherwise
    # expose any reference to a user object. Just pass around the
    # UUID without checking it, so we don't give away whether this
    # UUID is tied to any user.
    @uuid = uuid_param
  end

  # GET /resource/sign_up
  def new
    super do
      return render :bad_link if (signup_token.blank? && reset_password_token.blank?)

      # Only select the user by one of the two token options, because this
      # route allows setting a password for the account, and we need it
      # to be secure. Still don't reveal anything about which account was
      # tied to the token.
      user = find_user_by_signup_token || find_user_by_reset_password_token
      User.add_to_honeycomb_trace(user)

      if user.present? && user.registered?
        redirect_to cas_login_path(
          service: CanvasConstants::CANVAS_URL,
          notice: 'Looks like you have already signed up. Please log in.'
        ) and return
      end
    end
  end

  # POST /resource
  def create
    # Only select the user by one of the two token options, because this
    # route allows setting a password for the account, and we need it
    # to be secure.
    user = find_user_by_signup_token || find_user_by_reset_password_token
    User.add_to_honeycomb_trace(user)
    Honeycomb.add_field('registrations_controller.bad_link', false)

    # Act the same as #new, just in case someone tried to register again
    # with a tab that was open before or something.
    if user.present? && user.registered?
      redirect_to cas_login_path(
        service: CanvasConstants::CANVAS_URL,
        notice: 'Looks like you have already signed up. Please log in.'
      ) and return
    end

    # If the token was valid, run account registration.
    if user.present?
      # Register the new user in all of our systems.
      RegisterUserAccount.new(user, sign_up_params).run do |updated_user|
        if updated_user.errors.any? || !updated_user.persisted?
          if updated_user.errors.any? { |e| [:reset_password_token, :signup_token].include? e.attribute }
            # If the token expired, act the same as we do for invalid
            # tokens below. Don't reveal the exact reason for failure.
            Honeycomb.add_field('registrations_controller.bad_link', true)
            return render :bad_link
          end

          # At this point, it is safe to expose a reference to the user,
          # because the token is valid.
          # It is also necessary to expose a reference to the user, because
          # we need to be able to render the errors on that object.
          self.resource = updated_user
          return render :new
        end
      end
    else
      # If the token was invalid, show the error page.
      # This applies to already-used tokens, as well as tokens
      # that never existed to begin with.
      # Note that this means a bad-actor can check for valid tokens
      # by simply POSTing to this action.
      Honeycomb.add_field('registrations_controller.bad_link', true)
      return render :bad_link
    end

    # If account registration succeded, show the "thank you" page.
    # NOTE: Do *not* set self.resource, only pass the uuid.
    redirect_to action: :show, uuid: user.uuid
  end

  # GET /resource/edit
  # def edit
  #   super
  # end

  # PUT /resource
  # def update
  #   super
  # end

  # DELETE /resource
  # def destroy
  #   super
  # end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end
  #
  private

  def signup_token
    params[:signup_token] || params.dig(:user, :signup_token)
  end

  def reset_password_token
    params[:reset_password_token] || params.dig(:user, :reset_password_token)
  end

  def set_tokens
    @signup_token = signup_token
    @reset_password_token = reset_password_token
  end

  def uuid_param
    params[:uuid]
  end

  def find_user_by_signup_token
    User.with_signup_token(signup_token)
  end

  def find_user_by_reset_password_token
    User.with_reset_password_token(reset_password_token)
  end

  protected

  # If you have extra params to permit, append them to the sanitizer.
  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [:signup_token, :reset_password_token])
  end

  def sign_up_params
    devise_parameter_sanitizer.sanitize(:sign_up)
  end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_account_update_params
  #   devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
  # end

  # The path used after sign up (assuming they don't need to be confirmed). For signup waiting on confirmation, use the method below.
  #def after_sign_up_path_for(resource)
  #   super(resource)
  #end

  # The path used after sign up for inactive accounts.
  # This shows a thank you page and let's them know to go confirm their account.
  def after_inactive_sign_up_path_for(resource)
    users_registration_path(:signup_token => resource.signup_token)
  end

end
