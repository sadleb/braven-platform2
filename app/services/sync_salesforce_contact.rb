# frozen_string_literal: true
require 'salesforce_api'

# Sync's information unique to a Salesforce Contact record to Platform and Canvas.
class SyncSalesforceContact

  # @param [SalesforceAPI::SFContact] salesforce_contact
  # @param [Boolean] create_new_user_if_missing
  def initialize(salesforce_contact, create_new_user_if_missing)
    @salesforce_contact = salesforce_contact
    @create_new_user_if_missing = create_new_user_if_missing
  end

  # The Salesforce Contact is the source of truth for their User information. This service
  # creates or updates the User model to match the Contact. Returns nil if there is no
  # matching User and create_new_user_if_missing param is false, else returns the updated User.
  #
  # It also sends signup token to Salesforce, and emails the user a signup link
  # if that setting is on.
  #
  # Note: if the email changes for a registered user, we don't update the
  # Platform and Canvas email here until they confirm the change. We want the old email
  # to work until they confirm the new email in case it was an accident or mistake.
  # We only update Canvas if both Salesforce and Platform are in sync but somehow the
  # Canvas login email get out of sync (most likely an admin or engineer messing it up).
  def run
    Honeycomb.add_field('salesforce.contact.id', @salesforce_contact.id)
    Honeycomb.add_field('salesforce.contact.email', @salesforce_contact.email)

    @user = find_or_create_user()
    return nil unless @user.present?

    # Be careful to only add this to the span b/c when this is run as part of program sync
    # there is not a single "user" associated with this trace. We're instrumenting information
    # about multiple users in that case.
    @user.add_to_honeycomb_span('sync_salesforce_contact')

    @user.email = get_synced_email()

    # Note: we don't send these to Canvas at the moment. Rely on users to update
    # their own names or implement that later.
    @user.first_name = @salesforce_contact.first_name
    @user.last_name = @salesforce_contact.last_name

    # The most likely way this can fail to save is email conflicts. It's a unique column
    @user.save! if @user.changed?

    @user
  end

private

  # Finds or creates a new user if one doesn't exist depending on the
  # @create_new_user_if_missing setting.
  def find_or_create_user()
    @user = User.find_by(salesforce_id: @salesforce_contact.id)
    Honeycomb.add_field('user.present?', @user.present?)
    return @user if @user.present?
    return nil unless @create_new_user_if_missing

    new_user = User.new(
      email: @salesforce_contact.email,
      salesforce_id: @salesforce_contact.id,
      first_name: @salesforce_contact.first_name,
      last_name: @salesforce_contact.last_name,
    )

    # Don't send confirmation email yet; we do that at sign_up time instead.
    #
    # Note that there are 4 scenarios where the user gets this email to confirm
    # and activate their account:
    # 1) After they get a sign_up link, create their password, and register their account
    # 2) After they use the password reset link with an account that has never been registered,
    #    and are sent to create their account instead
    # 3) After manually requesting a new confirmation email when trying to log in with
    #    valid credentials for an unconfirmed account.
    # 4) After a staff member changes their login email (from Salesforce)
    new_user.skip_confirmation_notification!

    # NOTE: This can fail if there are duplicate Contacts with the same
    # email on Salesforce. This should be prevented by Salesforce.
    # Save before token generation, just because it makes it clearer
    # if validations fail.
    new_user.save!

    # Generate the signup token.
    raw_signup_token = new_user.set_signup_token!

    # Set these new User fields on the Salesforce Contact record
    # Note: call it with the raw token, *not* the encoded one from the database b/c that's
    # what is needed in the Account Create Link.
    salesforce_contact_fields_to_set = {
      'Platform_User_ID__c': new_user.id,
      'Signup_Token__c': raw_signup_token,
    }
    SalesforceAPI.client.update_contact(new_user.salesforce_id, salesforce_contact_fields_to_set)

    if @send_signup_emails
      new_user.send_signup_email!(raw_signup_token)
      Honeycomb.add_field('sync_salesforce_contact.signup_email_sent', true)
    end

    @user = new_user
  end

  # Returns the email that should be stored in Platform based on the sync logic where the
  # the Saleforce Participant is the source of truth, but they have to confirm any changes
  # after creating their account. Also handles syncing that email to Canvas in case it was
  # manually changed over there somehow (developer screw up or staff with admin access
  # changing the login email which is different from the primary email used for Canvas
  # communications / notifications).
  def get_synced_email
    platform_email = @user.email
    salesforce_email = @salesforce_contact.email.downcase

    if @user.unconfirmed_email&.downcase == salesforce_email
      Honeycomb.add_field('sync_salesforce_contact.email_changed', false)
      Honeycomb.add_field('sync_salesforce_contact.email_changed_details',
        'Email change was already requested and reconfirmation email sent. Skipping.')

    elsif @user.email.downcase == salesforce_email
      Honeycomb.add_field('sync_salesforce_contact.email_changed', false)
      Honeycomb.add_field('sync_salesforce_contact.email_changed_details', 'Salesforce email matches Platform email')
      # TODO: if we accelerate how often the sync runs, we don't want to do
      # this everytime. Maybe only do this if there are changes to the last synced value?
      # e.g. changing their name or email causes us to make sure Canvas is good too,
      # but we don't blindly do this everytime? https://app.asana.com/0/1201131148207877/1201515686512766
      #
      # Ensure that even if Salesforce and Platform are in sync, the Canvas login email
      # is as well. NOOP if they are.
      SyncUserEmailToCanvas.new(@user).run! if @user.has_canvas_account?

    else
      Honeycomb.add_field('sync_salesforce_contact.email_changed', true)
      change_message = "Email changed in Salesforce to #{@salesforce_contact.email}. Updating user from old email #{@user.email}."
      change_message += " Sending reconfirmation link to the new one." if @user.registered?
      Honeycomb.add_field('sync_salesforce_contact.email_changed_details', change_message)
      Rails.logger.info(change_message)

      # Change their email.
      #
      # Generally, Devise will send a reconfirmation email so they are aware their account changed
      # and can activate it. Requiring reconfirmation is also a safegaurd against staff
      # setting an email that someone doesn't actually control (e.g. something with a typo)
      # and then telling them to use it to login. The person must actually have access to
      # the email address for the account to be active and able to login with it.
      # The old email continues to work for Canvas login until they activate the new one.
      #
      # On save, this doesn't actually set the `email` column if they're registered.
      # It set's the `unconfirmed_email` column until they actually confirm the change.
      # However, if they're unregistered it will directly set the new email without requiring confirmation
      # since they end-user hasn't done anything yet and we're just getting our backend systems in sync.
      # We've monkey patched the User model to override Devise's confirmable behavior for this to work.
      platform_email = salesforce_email
    end
    platform_email
  end

end
