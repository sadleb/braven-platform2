# frozen_string_literal: true

# Fully registers and creates a new User account in all of our systems
# (aka Platform, Canvas and Salesforce) so that it's ready for use.
# Everything must be consistent and in sync so the systems can work together.
class RegisterUserAccount
  RegisterUserAccountError = Class.new(StandardError)

  # The params should include `password`, `password_confirmation`, and *either*
  # `signup_token` OR `reset_password_token`.
  def initialize(sign_up_params)
    # We want Salesforce to be the source of truth, especially for their email, to avoid
    # duplicating user accounts. When they register their user account, we look up
    # the local account by the signup or reset token, grab their Salesforce ID, then
    # look up on Salesforce the rest of the info they gave us when they signed up / applied.
    # Note the tokens may be expired here, we don't check that until later.
    @user = find_user_by_tokens(sign_up_params)
    # Keep a reference to the params so we know which token(s) to check for expiry.
    @sign_up_params = sign_up_params

    # If the user doesn't exist, we'll error out at this point.
    # This doesn't expose user enumeration in RegistrationsController#create because
    # we've already verified the user by token there. But if that changes, or we use
    # this service elsewhere, be sure to appropriately handle this exception.
    @salesforce_participant = sf_client.find_participant(contact_id: @user.salesforce_id)
    @salesforce_program = sf_client.find_program(id: @salesforce_participant.program_id)

    # When we update the user, pass in the password and the latest Salesforce info.
    # (But not the tokens.)
    @register_user_params = sign_up_params
      .slice(:password, :password_confirmation)
      .merge(salesforce_contact_params)
  end

  def run
    Honeycomb.start_span(name: 'register_user_account.run') do |span|
      span.add_field('app.salesforce.contact.id', @user.salesforce_id)
      span.add_field('app.user.id', @user.id)
      span.add_field('app.user.email', @user.email)
      span.add_field('app.register_user_account.salesforce_email', @register_user_params[:email])

      # Mimic Devise's reset_password_by_token behavior for expired tokens.
      # https://github.com/heartcombo/devise/blob/57d1a1d3816901e9f2cc26e36c3ef70547a91034/lib/devise/models/recoverable.rb#L145
      # Note if someone tries to use both tokens at once (why??) and one is expired but
      # the other isn't, we act the same as if both were expired. Because that's easier.
      if @sign_up_params[:signup_token].present? && !@user.signup_period_valid?
        span.add_field('app.register_user.signup_token_expired', true)
        @user.errors.add(:signup_token, :expired)
        yield @user if block_given?
        return
      end
      if @sign_up_params[:reset_password_token].present? && !@user.reset_password_period_valid?
        span.add_field('app.register_user.reset_password_token_expired', true)
        @user.errors.add(:reset_password_token, :expired)
        yield @user if block_given?
        return
      end

      # Don't send confirmation email yet; we do it explicitly below.
      @user.skip_confirmation_notification!
      @user.update(@register_user_params.merge({
        # Mark the user as fully registered.
        registered_at: DateTime.now.utc,
        # Clear the signup and reset tokens, regardless of which was used.
        # https://github.com/heartcombo/devise/blob/57d1a1d3816901e9f2cc26e36c3ef70547a91034/lib/devise/models/recoverable.rb#L83
        signup_token: nil,
        signup_token_sent_at: nil,
        reset_password_token: nil,
        reset_password_sent_at: nil,
      }))
      span.add_field('app.register_user.user_update_errors', @user.errors.to_json)
      # Allow error handling on model validation when called from a controller.
      yield @user if block_given?

      # Create a user in Canvas.
      create_canvas_user!
      span.add_field('app.canvas.user.id', @user.canvas_user_id)

      # Update Salesforce with the signup date and Canvas User ID.
      sf_client.update_contact(@user.salesforce_id, {
        'Canvas_Cloud_User_ID__c': @user.canvas_user_id,
        'Signup_Date__c': DateTime.now.utc,
      })
      span.add_field('app.register_user_account.salesforce_updated', true)

      # If this fails, there is nothing to roll back. We just need to retry it and/or
      # fix the bug after finding out that they can't see the proper course content.
      sync_canvas_enrollment!
      span.add_field('app.register_user_account.canvas_enrollment_synced', true)

      # Modify user notification settings to be less spammy.
      # We do this last because it's the least important (in case of failure).
      # If it fails, just log stuff, don't raise an exception.
      update_canvas_user_settings

      # Send confirmation email.
      @user.send_confirmation_instructions
    end

    # Note: we actually don't want to roll anything back if there are failures. We wouldn't
    # want to accidentailly delete a Canvas user and their work, or a Platform user and their
    # work. Instead, we're adding fields to the Honeycomb span to more easily diagnose and
    # troubleshoot the issues. As things arise, we should enhance this code to be re-runnable
    # so that if it fails you just have to try again and it will work if the underlying issue
    # is fixed.
  end

private

  # Expects one of {:signup_token => 'TOKEN'} OR {:reset_password_token => 'TOKEN'}.
  def find_user_by_tokens(params)
    return User.with_signup_token(params[:signup_token]) if params[:signup_token]
    return User.with_reset_password_token(params[:reset_password_token]) if params[:reset_password_token]
  end

  def sync_canvas_enrollment!
    # TODO: rename Portal to Canvas everywhere.
    SyncPortalEnrollmentForAccount
      .new(user: @user,
           portal_user: CanvasAPI::LMSUser.new(@user.canvas_user_id, @user.email),
           salesforce_participant: @salesforce_participant,
           salesforce_program: @salesforce_program)
      .run
  end

  def create_canvas_user!
    unless salesforce_participant_enrolled?
      raise RegisterUserAccountError, "Salesforce Contact ID not enrolled: #{@user.salesforce_id}"
    end

    canvas_user = CanvasAPI.client.create_user(
      @salesforce_participant.first_name,
      @salesforce_participant.last_name,
      @salesforce_participant.email,  # username
      @salesforce_participant.email,
      @salesforce_participant.contact_id,
      @salesforce_participant.student_id,
      @salesforce_program.timezone
    )
    @user.update!(canvas_user_id: canvas_user['id'])
  end

  def update_canvas_user_settings
    # Note: Several Canvas API calls are wrapped in this one method.
    CanvasAPI.client.disable_user_grading_emails(@user.canvas_user_id)

  rescue RestClient::Exception => e
    # The RestClient autoinstrumentation already sends response info.
    Honeycomb.add_field('error', e.class.name)
    Honeycomb.add_field('error_detail', e.message)
    Honeycomb.add_field('alert.register_user_account.update_settings_failed', true)
    Sentry.capture_exception(e)
    Rails.logger.warn("Failed to update user notification preferences for #{@user.canvas_user_id}: #{e.message}")
  end

  # The new user params where Salesforce is the source of truth
  def salesforce_contact_params
    {
      email: @salesforce_participant.email,
      first_name: @salesforce_participant.first_name,
      last_name: @salesforce_participant.last_name,
    }
  end

  def salesforce_participant_enrolled?
    @salesforce_participant.status.eql?(SalesforceAPI::ENROLLED)
  end

  def sf_client
    @sf_client ||= SalesforceAPI.client
  end

end
