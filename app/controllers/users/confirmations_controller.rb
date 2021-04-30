# frozen_string_literal: true

class Users::ConfirmationsController < Devise::ConfirmationsController
  include RubyCAS::Server::Core::Tickets

  layout 'accounts'
  before_action :configure_permitted_parameters

  # GET /resource/confirmation/new
  # def new
  #   super
  # end

  # POST /resource/confirmation
  def create
    super do
      self.resource = User.find_by(salesforce_id: params[:user][:salesforce_id])
      resource.send_confirmation_instructions
    end
  end

  # GET /resource/confirmation?confirmation_token=abcdef
  def show

    # Taken from: https://github.com/heartcombo/devise/blob/5d5636f03ac19e8188d99c044d4b5e90124313af/lib/devise/models/confirmable.rb#L362
    # which is what super does to look up the resource (aka user)
    user_before_confirmation = User.find_first_by_auth_conditions(confirmation_token: params[:confirmation_token])
    rollback_params = {
      email: user_before_confirmation.email,
      unconfirmed_email: user_before_confirmation.unconfirmed_email,
      confirmation_token: user_before_confirmation.confirmation_token,
      confirmed_at: user_before_confirmation.confirmed_at
    } if user_before_confirmation

    # Note: we're explicity not using the Devise "resource" attribute b/c we don't
    # render a view and Devise ends up disclosing information we shouldn't be
    # in other Devise paths that we've been stripping out.
    user = User.confirm_by_token(params[:confirmation_token])

    if user.errors.empty?

      ConfirmUserAccount.new(user).run!

      Honeycomb.add_field('confirmations_controller.auto_sign_in', true)
      Rails.logger.debug("Signing #{user.email} in using CAS SSO.")
      redirect_path_for_user = sign_in_and_get_redirect_path
      set_flash_message!(:notice, :confirmed)
      redirect_to redirect_path_for_user and return
    else
      # This is most likely for a bad token or a token that's already been consumed or
      # an expired token. Don't reveal any information about the token's validity or the
      # account tied to it for security purposes. Just send them to the log in page and
      # if they use valid credentials, then they'll get a message about the problem (e.g.
      # they have to resend a confirmation email b/c the link expired).
      Rails.logger.error("Confirmation error for #{user.inspect}. Errors = #{user.errors.full_messages}")
      Honeycomb.add_field('user.email', user.email)
      Honeycomb.add_field('error', user.errors.class.name)
      Honeycomb.add_field('error_detail', user.errors.full_messages)
      redirect_to cas_login_path(
          service: CanvasAPI.client.canvas_url,
          notice: 'Your email is either already confirmed or that link was invalid. Please log in.'
        ) and return
    end
  rescue RestClient::Exception => e
    # This is a CanvasAPI failure. Presumably the API is down (but it could be a bug).
    # Rollback the consumption of the token so they can try again in a little bit and
    # everything will be setup properly instead of waiting for the nightly sync or a
    # staff member to trigger it. Note: don't do a database transaction to handle the
    # rollback b/c this is a network call that can take time.
    Honeycomb.add_field('alert.confirmations_controller.confirmation_failed', true)
    Rails.logger.error(e.message)
    if user && rollback_params
      user.skip_reconfirmation!
      user.update(rollback_params)
      Honeycomb.add_field('alert.confirmations_controller.confirmation_rollback', true)
    end
    raise
  end

  protected

  # The path used after resending confirmation instructions.
  def after_resending_confirmation_instructions_path_for(_)
    new_user_confirmation_path
  end

#  # The path used after confirmation.
#  def after_confirmation_path_for(resource_name, resource)
#    cas_login_url
#  end

  # Does a CAS SSO login for the app they are redirected to on login. E.g. if they have Canvas access,
  # auto-log them in there, otherwise do it here in the platform.
  def sign_in_and_get_redirect_path
     username = resource.email
     if resource.canvas_user_id
       login_service_url = URI.join(CanvasAPI.client.canvas_url, "/login/cas").to_s
     else
       login_service_url = ::Devise.cas_service_url(request.url, devise_mapping)
     end

     # TGT = Ticket Granting Ticket helper, ST = Service Ticket helper. See: lib/rubycas-server-core/tickets.rb
     tgt = TGT.create! username, ::Devise.cas_client
# TODO: do we need to filter this cookie?
     response.set_cookie('tgt', tgt.to_s) # When the app calls back to validate the ticket, this is what makes that work.
     st = ST.create! login_service_url, username, tgt, ::Devise.cas_client

     Rails.logger.debug("Done signing in confirmed user #{username} with CAS Ticket granting cookie and Service Ticket")

     Utils.build_ticketed_url(login_service_url, st)
  end

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:create, keys: [:salesforce_id])
  end

end
