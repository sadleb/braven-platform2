# frozen_string_literal: true

class SyncFromSalesforceContact

  # @param [User] user
  # @param [SalesforceAPI::SFContact] salesforce_contact
  def initialize(user, salesforce_contact)
    @user = user
    @salesforce_contact = salesforce_contact
  end

  # The Salesforce Contact is the source of truth for their email (and name). This service
  # updates Platform to match if the email changes.
  #
  # Note: if the change was in Salesforce, we don't also update the Canvas email
  # here b/c we want the old email to work until they confirm the new email in
  # case it was an accident or mistake. We only update Canvas if both Salesforce
  # and Platform are in sync but somehow the Canvas login email get out of sync
  # (most likely an admin or engineer messing it up).
  def run!
    Honeycomb.add_field('salesforce.contact.email', @salesforce_contact.email)

    if @user.unconfirmed_email&.downcase == @salesforce_contact.email.downcase
      Honeycomb.add_field('sync_from_salesforce_contact.email_changed', false)
      Honeycomb.add_field('sync_from_salesforce_contact.email_changed_details', 'Email change was already requested and reconfirmation email sent. Skipping.')
      return
    elsif @user.email.downcase == @salesforce_contact.email.downcase
      Honeycomb.add_field('sync_from_salesforce_contact.email_changed', false)
      # Ensure that even if Salesforce and Platform are in sync, the Canvas login email
      # is as well. NOOP if they are.
      SyncUserEmailToCanvas.new(@user).run!
      return
    end

    Honeycomb.add_field('sync_from_salesforce_contact.email_changed', true)
    Rails.logger.info("Email changed in Salesforce to #{@salesforce_contact.email}. Updating user from old email #{@user.email} and sending reconfirmation link to the new one.")

    # The most likely way this can fail is email conflicts. It's a unique column
    # Note that this doesn't actually set the `email` column. It set's the
    # `unconfirmed_email` column until they actually confirm.
    #
    # This sends a reconfirmation email so they are aware their account changed
    # and can activate it. Requiring reconfirmation is also a safegaurd against staff
    # setting an email that someone doesn't actually control (e.g. something with a typo)
    # and then telling them to use it to login. The person must actually have access to
    # the email address for the account to be active and able to login with it.
    # The old email continues to work for Canvas login until they activate the new one.
    @user.update!(email: @salesforce_contact.email,
                  first_name: @salesforce_contact.first_name,
                  last_name: @salesforce_contact.last_name,
    )
    Honeycomb.add_field('user.unconfirmed_email', @user.unconfirmed_email)
    Honeycomb.add_field('sync_from_salesforce_contact.reconfirmation_email_sent', true)
  end

end
