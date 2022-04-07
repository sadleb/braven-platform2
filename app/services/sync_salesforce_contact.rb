# frozen_string_literal: true
require 'canvas_api'
require 'salesforce_api'

class SyncSalesforceContact
  include Rails.application.routes.url_helpers

  def initialize(salesforce_contact_id, time_zone=nil)
    @salesforce_contact_id = salesforce_contact_id
    @time_zone = time_zone
  end

  # The Salesforce Contact is the source of truth for their User information. This service
  # creates or updates the local Platform user to match the Contact. Returns the updated
  # local User model.
  #
  # If it's a new User, this service also creates new Canvas users. However, future changes
  # to the Contact, like their name or email, are synced to Canvas by the
  # SyncSalesforceParticipant service
  #
  # This method is re-runnable in the case of failures. Whatever failed the first time
  # will be fixed assuming the underlying issue is fixed. E.g. if we fail to create
  # the Canvas user the first time, we'll try again each sync until it works.
  #
  # Note: if the email changes for a registered user, we don't update the
  # Platform and Canvas email here until they confirm the change. We want the old email
  # to work until they confirm the new email in case it was an accident or mistake.
  # We only update Canvas if both Salesforce and Platform are in sync but somehow the
  # Canvas login email get out of sync (most likely an admin or engineer messing it up).
  def run
    Honeycomb.start_span(name: 'sync_salesforce_contact.run') do
      Honeycomb.add_field('salesforce.contact.id', @salesforce_contact_id)

      @salesforce_email = salesforce_contact.email.downcase
      Honeycomb.add_field('salesforce.contact.email', @salesforce_email)

      # 1) Sync Platform and Salesforce
      if user.blank?
        create_local_user()

      else # sync existing user
        user.add_to_honeycomb_span('sync_salesforce_contact')

        # We could have created the local user but the SalesforceAPI call failed.
        # Instead of trying to rollback (and increasing the id column in the Users table),
        # just keep trying to send it to Salesforce in subsequent syncs.
        send_user_id_to_salesforce(user) if salesforce_contact.user_id.blank?

        user.email = get_synced_email()
        user.first_name = salesforce_contact.first_name
        user.last_name = salesforce_contact.last_name
        save_user!(user) if user.changed?
      end

      # 2) Sync Platform and Canvas
      #
      # Note that we do this for both new users and existing users so that it's re-runnable
      # in the case of failures the first time. E.g. the Canvas API create_user call failed
      # after creating their local Platform user.
      if user.canvas_user_id.blank?
        create_canvas_user()
        update_canvas_user_settings()
      end

      # 3) Finish sync and generate Account Creation link in Salesforce. User can now sign up.
      #
      # Since we do the signup_token last, if any previous failures happened in a prior run
      # and we never successfully send it to Salesforce,  it's safe to regenerate a new
      # signup_token and try again to set that in Salesforce.
      # In other words, if there are any failures in any of the steps, those will be retried
      # on the next sync. It's only once everything has been successfuly sent to Salesforce
      # that the signup_token_sent_at is set locally. At that point, the Contact sync becomes
      # a NOOP in future syncs until there are actual changes.
      if user.signup_token_sent_at.blank?
        setup_signup_token()
      else
        validate_already_synced_contact!
      end

    end

    user
  end

  # If we're running the Contact sync and everything seems to have been setup
  # properly the first time, check if something got messed up later and alert
  # so we can fix it manually if things will still work. Throw if things would
  # be broken for the end-user
  def validate_already_synced_contact!
    unless user.canvas_user_id.present?
      msg = "The Salesforce Contact ID: '#{user.salesforce_id}' doesn't have " +
            "a Canvas User ID set in Platform."
      Honeycomb.add_support_alert('missing_canvas_user_id', msg, :error)
      raise SyncSalesforceProgram::UserSetupError, msg
    end

    unless salesforce_contact.user_id.to_i == user.id
      msg = "The Salesforce Contact ID: '#{user.salesforce_id}' doesn't have " +
            "their 'Platform User ID' field set properly in Salesforce. It should be set to: #{user.id}."
      Honeycomb.add_support_alert('mismatched_platform_user_id', msg, :warn)
      # Don't raise b/c things should still work for the end user. We just need to fix this up on the backend
    end

    unless salesforce_contact.canvas_user_id.to_i == user.canvas_user_id
      msg = "The Salesforce Contact ID: '#{user.salesforce_id}' doesn't have " +
            "their 'Canvas User ID' field set properly in Salesforce. It should be set to: #{user.canvas_user_id}."
      Honeycomb.add_support_alert('mismatched_canvas_user_id', msg, :warn)
      # Don't raise b/c things should still work for the end user. We just need to fix this up on the backend
    end

    sync_signup_date()

    salesforce_contact
  end

  def send_signup_date_to_salesforce(date_time=DateTime.now.utc)
    sf_client.update_contact(user.salesforce_id, {
      'Signup_Date__c': date_time,
    })

  rescue => e
    # Don't throw if this fails. It shouldn't prevent the end-user from using
    # Canvas or the platform. Just keep retrying in future syncs.
    msg = "Failed to set the 'Signup_Date__c' in Salesforce for Contact ID: '#{user.salesforce_id}' "
          "The dashboard for sign-ups will be innaccurate until this is resolved."
          "\nError: #{e.inspect}"
    Honeycomb.add_alert('send_signup_date_to_salesforce_failed', msg, :warn)
  end

  # Changes the email in Canvas to match Platform. Generally, you should rely on the
  # SIS Import to sync the local user to Canvas, but this can be used if it needs to
  # happen on-demand, like during the user confirmation flow.
  def sync_canvas_email
    Honeycomb.start_span(name: 'sync_salesforce_contact.change_canvas_email') do
      canvas_login = CanvasAPI.client.get_login(@user.canvas_user_id)
      canvas_login_email = canvas_login['unique_id']
      Honeycomb.add_field('canvas.login.unique_id', canvas_login_email)

      canvas_email_matches_platform = (canvas_login_email.downcase == @user.email.downcase)
      Honeycomb.add_field('sync_salesforce_contact.email_matches?', canvas_email_matches_platform)

      unless canvas_email_matches_platform
        # Note that login emails and the email that Canvas sends Notifications to are
        # completely separate. This only changes the login email. The other default communication
        # email will be adjusted in the next sync when we send a new users.csv in the SisImport.

        CanvasAPI.client.update_login(canvas_login['id'], @user.email)

        Rails.logger.info("Done changing Canvas login email from #{canvas_login_email} to #{@user.email}.")
      end
    rescue RestClient::Exception => e
      msg = "Failed to change the email in Canvas from '#{canvas_login_email}' to '#{@user.email}'. " +
            "This user may have trouble logging in until this is resolved."
      Honeycomb.add_alert('change_canvas_email_failed', msg, :error)
      raise
    end
  end

private

  def salesforce_contact
    @salesforce_contact ||= HerokuConnect::Contact.find_by(sfid: @salesforce_contact_id)
    unless @salesforce_contact.present?
      msg = "Salesforce Contact ID: '#{@salesforce_contact_id}' not found. " +
            "Maybe it was merged wrong?"
      existing_user = User.find_by(salesforce_id: @salesforce_contact_id)
      if existing_user.present?
        msg << " The user is: #{existing_user.email}. Their Salesforce ID must be updated here: #{user_url(existing_user)}"
      end
      Honeycomb.add_support_alert('missing_salesforce_contact', msg, :error)
      raise SyncSalesforceProgram::MissingContactError, msg
    end

    @salesforce_contact
  end

  def user
    @user ||= User.find_by(salesforce_id: salesforce_contact.sfid)
  end

  def create_local_user
    @user = User.new(
      first_name: salesforce_contact.first_name,
      last_name: salesforce_contact.last_name,
      email: @salesforce_email,
      salesforce_id: salesforce_contact.sfid
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
    @user.skip_confirmation_notification!

    # NOTE: This can fail if there are duplicate Contacts with the same
    # email on Salesforce. This should be prevented by Salesforce but isn't.
    # There is also a race condition where a second Program sync job tries to
    # create the user first. It will fail here due to validations. Do this before
    # token generation so it's clear what happened.
    save_user!(@user)
    @user.add_to_honeycomb_span('sync_salesforce_contact')

    # Send the ID to Salesforce now instead of waiting until the end
    # when everything else works b/c we now have a valid local User and
    # want to prevent duplicate Salesforce Contacts from being merged wrong.
    # There is a validation in Salesforce that doesn't let you delete
    # a Contact with the Platform User ID set during a merge.
    send_user_id_to_salesforce(@user)

    Honeycomb.add_field('sync_salesforce_contact.create_local_user.success?', true)

    @user
  end

  # The most likely way this can fail to save is email or salesforce_id conflicts.
  # They're unique columns
  def save_user!(user)
    user.save!
  rescue ActiveRecord::RecordInvalid => e2
    ar_error = e2.record.errors.first
    if ar_error.attribute == :email && ar_error.type == :taken
      existing_user = User.find_by_email(salesforce_contact.email)
      msg = <<-EOF
There are duplicate Contacts in Salesforce with the email: #{salesforce_contact.email}. Open the Contact with ID: #{existing_user.salesforce_id} and use the "Duplicate Check -> Merge" tool to get rid of the duplicate. Make sure and choose Contact #{existing_user.salesforce_id} as the Master record!

For reference, the existing Platform user is: #{user_url(existing_user)} and the duplicate Contact ID is: #{salesforce_contact.sfid}.
EOF
      Honeycomb.add_support_alert('save_user_failed', msg, :error)
      raise SyncSalesforceProgram::DuplicateContactError, msg
    else
      raise
    end
  end

  def send_user_id_to_salesforce(new_user)
    salesforce_fields_to_set = {
      'Platform_User_ID__c': new_user.id,
    }
    sf_client.update_contact(new_user.salesforce_id, salesforce_fields_to_set)
  rescue => e
    msg = "Failed to send the new Platform User ID: #{new_user.id} to Salesforce for " +
          "Contact ID: #{salesforce_contact.sfid}. This will keep retrying until the " +
          "underlying issue is fixed or you manually set it in Salesforce.\nError: #{e.inspect}"
    Honeycomb.add_alert('send_user_id_to_salesforce_failed', msg, :error)
    raise SyncSalesforceProgram::UserSetupError, msg
  end

  def create_canvas_user

    canvas_user = CanvasAPI.client.create_user(
      salesforce_contact.first_name,
      salesforce_contact.last_name,
      @salesforce_email,
      user.sis_id,
      @time_zone
    )
    canvas_user_id = canvas_user['id']
    # matches what user.add_to_honeycomb_span('sync_salesforce_contact') adds
    Honeycomb.add_field('sync_salesforce_contact.user.canvas_user_id', canvas_user_id.to_s)

    # Update the local user but do NOT send the ID to Salesforce yet.
    # Do that along with the signup_token b/c the combination of a signup_token
    # and canvas_user_id in Salesforce is what we use to determine that the
    # sync worked and they can now create an account.
    user.update!(canvas_user_id: canvas_user_id)

  rescue => e
    msg = "Failed to create a Canvas user for Contact ID: #{salesforce_contact.sfid}. This " +
          "will keep retrying until the underlying issue is fixed.\nError: #{e.inspect}"
    Honeycomb.add_alert('create_canvas_user_failed', msg, :error)
    raise SyncSalesforceProgram::UserSetupError, msg
  end

  # Last step in creating a fully synced Contact that can now
  # signup and create an account. This only only considered successful
  # if the signup_token and canvas_user_id actually make it to Salesforce.
  #
  # Notes:
  # - call it with the raw token, *not* the encoded one from the database b/c that's
  #   what is needed in the Account Create Link.
  # - send the canvas_user_id at this time because it's messy on the Salesforce side
  #   to have that if they can't actually signup yet.
  # - the Canvas SIS Import sync could still fail and they won't have proper access
  #   once they login, but it's too complicated to wait for that to work before
  #   letting them signup. We'll get alerts and hopefully fix it before they get
  #   that far, but otherwise we'll just handle that through support tickets.
  def setup_signup_token
    raw_signup_token = user.set_signup_token!

    salesforce_fields_to_set = {
      'Canvas_Cloud_User_ID__c': user.canvas_user_id,
      'Signup_Token__c': raw_signup_token,
    }
    sf_client.update_contact(user.salesforce_id, salesforce_fields_to_set)
    Honeycomb.add_field('sync_salesforce_contact.new_user_setup_done', true)
  rescue => e
    # We don't want the local signup_token_sent_at set unless it was successfully sent to
    # Salesforce. That's the final step in the user creation process. Unset it on
    # errors. Note that we can't unset the signup_token itself b/c that happens normally
    # when they register and consume it.
    msg = "Failed to generate a signup_token and send it to Salesforce for " +
          "Contact ID: #{salesforce_contact.sfid}. This will keep retrying until the " +
          "underlying issue is fixed.\nError: #{e.inspect}"
    Honeycomb.add_alert('setup_signup_token_failed', msg, :error)
    user.update!(signup_token_sent_at: nil)
    Honeycomb.add_field('sync_salesforce_contact.signup_token_unset', true)
    raise SyncSalesforceProgram::UserSetupError, msg
  end

  # Make is less noisy for users by turning off grade notifications. These happen
  # alot with the automatic Module grade.
  # If it fails, just log stuff, don't raise an exception.
  def update_canvas_user_settings()
    # Note: Several Canvas API calls are wrapped in this one method.
    CanvasAPI.client.disable_user_grading_emails(user.canvas_user_id)

  rescue RestClient::Exception => e
    msg = "Failed to update user notification preferences to turn off grading notifications for " +
          "#{user.email} (Canvas User Id: #{user.canvas_user_id}). We will not retry this, but " +
          "this user may get bombarded with emails from Canvas when they work on the Modules"
    Honeycomb.add_alert('update_canvas_user_settings_failed', msg, :warn)
    Sentry.capture_exception(e)
  end

  # Returns the email that should be stored in Platform based on the sync logic where the
  # the Saleforce Participant is the source of truth, but they have to confirm any changes
  # after creating their account. Also handles syncing that email to Canvas in case it was
  # manually changed over there somehow (developer screw up or staff with admin access
  # changing the login email which is different from the primary email used for Canvas
  # communications / notifications).
  def get_synced_email
    platform_email = user.email.downcase
    salesforce_email = @salesforce_email.downcase

    if user.unconfirmed_email&.downcase == salesforce_email
      Honeycomb.add_field('sync_salesforce_contact.email_changed', false)
      Honeycomb.add_field('sync_salesforce_contact.email_changed_details',
        'Email change was already requested and reconfirmation email sent. Skipping.')

    elsif platform_email == salesforce_email
      Honeycomb.add_field('sync_salesforce_contact.email_changed', false)
      Honeycomb.add_field('sync_salesforce_contact.email_changed_details', 'Salesforce email matches Platform email')

    else
      Honeycomb.add_field('sync_salesforce_contact.email_changed', true)
      Honeycomb.add_field('sync_salesforce_contact.email_changed.old', user.email)
      Honeycomb.add_field('sync_salesforce_contact.email_changed.new', salesforce_email)
      change_message = "Email changed in Salesforce to #{salesforce_email}. Updating user from old email #{user.email}."
      change_message += " Sending reconfirmation link to the new one." if user.registered?
      Honeycomb.add_field('sync_salesforce_contact.email_changed_details', change_message)
      Rails.logger.info(change_message)

      # Return the changed value indicating it should be saved.
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

  # The Salesforce API could fail but we don't want that to impact the end user.
  # Just retry sending the date if it never made it to Salesforce.
  def sync_signup_date
    return unless user.registered?

    if salesforce_contact.signup_date__c.blank?
      Honeycomb.add_field('sync_salesforce_contact.sync_signup_date.retrying', true)
      send_signup_date_to_salesforce(user.registered_at)
    end
  end

  def sf_client
    @sf_client ||= SalesforceAPI.client
  end

end
