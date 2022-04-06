# frozen_string_literal: true

class Users::ConfirmationsController < Devise::ConfirmationsController
  include RubyCAS::Server::Core::Tickets

  layout 'accounts'
  before_action :configure_permitted_parameters

  # GET /resource/confirmation/new
  # def new
  #   super
  # end

  # GET /resource/confirmation/show_resend
  def show_resend
    # Don't set any self.resource reference, this endpoint should
    # not reveal any information. The view references params directly
    # if they are set.
  end

  # POST /resource/confirmation
  # This is used to re-send confirmation instructions if they lost the email
  # or if the token is invalid.
  def create
    # Don't error out, and don't reveal whether the UUID (or confirmation_token)
    # was valid. Just try to send an email if the user exists and then tell them
    # to check their email.
    user = find_user_by_uuid || find_user_by_confirmation_token
    User.add_to_honeycomb_trace(user)
    user&.send_confirmation_instructions
    redirect_to new_user_confirmation_path
  end

  # GET /resource/confirmation?confirmation_token=abcdef
  def show
    # Add info to Honeycomb, without revealing on the frontend
    # whether this confirmation token was actually valid.
    user_before_confirmation = User.find_first_by_auth_conditions(confirmation_token: params[:confirmation_token])
    User.add_to_honeycomb_trace(user_before_confirmation)
  end

  # POST /resource/confirmation/confirm
  def confirm
    # Taken from: https://github.com/heartcombo/devise/blob/5d5636f03ac19e8188d99c044d4b5e90124313af/lib/devise/models/confirmable.rb#L362
    # which is what confirmable#show does to look up the resource (aka user)
    user_before_confirmation = find_user_by_confirmation_token
    rollback_params = {
      email: user_before_confirmation.email,
      unconfirmed_email: user_before_confirmation.unconfirmed_email,
      confirmation_token: user_before_confirmation.confirmation_token,
      confirmed_at: user_before_confirmation.confirmed_at
    } if user_before_confirmation

    # Note: we're explicity not using the Devise "resource" attribute b/c we don't
    # render a view and Devise ends up disclosing information we shouldn't be
    # in other Devise paths that we've been stripping out.
    # Also note that confirm_by_token() returns a new empty User with errors set
    # if the token was invalid.
    user = User.confirm_by_token(confirmation_token_param)

    # Explicitly add this user to the trace since we didn't know who was hitting
    # this endpoint until now.
    User.add_to_honeycomb_trace(user)

    if user.errors.empty?
      sync_contact_service = SyncSalesforceContact.new(user.salesforce_id)
      @salesforce_contact = sync_contact_service.validate_already_synced_contact!
      # The user could be confirming an email change, not just their original email.
      # We need it to immediately work when it's being changed.
      sync_contact_service.sync_canvas_email
      Rails.logger.info("Finished account confirmation for #{user.inspect}.")

      Honeycomb.add_field('confirmations_controller.auto_sign_in', true)
      Rails.logger.debug("Signing #{user.email} in using CAS SSO.")
      # Must set self.resource before calling sign_in_and_get_redirect_path.
      self.resource = user
      redirect_path_for_user = sign_in_and_get_redirect_path
      set_flash_message!(:notice, :confirmed)
      redirect_to redirect_path_for_user and return
    else
      # This is most likely for a bad token or a token that's already been consumed or
      # an expired token. Don't reveal any information about the token's validity or the
      # account tied to it for security purposes. Just send them to the #show_resend view so they
      # get a "re-send confirmation email" button. If the token was attached to a real
      # account, the button will work. If not, the button will act like it worked but do
      # nothing.
      Rails.logger.error("Confirmation error for #{user.inspect}. Errors = #{user.errors.full_messages}")
      Honeycomb.add_field('error', user.errors.class.name)
      Honeycomb.add_field('error_detail', user.errors.full_messages)
      Honeycomb.add_field('error_type', user.errors.first.type) # e.g. confirmation_period_expired
      redirect_to users_confirmation_show_resend_path(
        confirmation_token: confirmation_token_param
      ) and return
    end
  rescue => e
    # Rollback the consumption of the token so they can try again once the underlying
    # issue is fixed everything will be setup properly instead of requiring them to
    # generate a new token themselves (or having a staff member do it).
    # Note: don't do a database transaction to handle the
    # rollback b/c this is a network call that can take time.
    Honeycomb.add_alert('confirm_failed', "Failed to confirm the email address for #{user.inspect}")
    Rails.logger.error(e.message)
    if user && rollback_params
      user.skip_reconfirmation!
      user.update(rollback_params)
      Honeycomb.add_field('confirmations_controller.confirmation_rollback', true)
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
     login_service_url = helpers.default_service_url_for(resource)

     # TGT = Ticket Granting Ticket helper, ST = Service Ticket helper. See: lib/rubycas-server-core/tickets.rb
     tgt = TGT.create! username, ::Devise.cas_client
# TODO: do we need to filter this cookie?
     response.set_cookie('tgt', tgt.to_s) # When the app calls back to validate the ticket, this is what makes that work.
     st = ST.create! login_service_url, username, tgt, ::Devise.cas_client

     Rails.logger.debug("Done signing in confirmed user #{username} with CAS Ticket granting cookie and Service Ticket")

     Utils.build_ticketed_url(login_service_url, st)
  end

  private

  # Note this uses the nested syntax expected in the #create action.
  def find_user_by_uuid
    User.find_by(uuid: params[:user][:uuid])
  end

  # Note this uses the nested syntax expected in the #create action.
  def confirmation_token_param
    params.dig(:user, :confirmation_token)
  end

  def find_user_by_confirmation_token
    User.find_first_by_auth_conditions(confirmation_token: confirmation_token_param)
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:create, keys: [:uuid, :confirmation_token])
  end

end
