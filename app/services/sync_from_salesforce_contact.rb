# frozen_string_literal: true
require 'canvas_api'
require 'salesforce_api'

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
  # Note that we also update their name IFF we have to change the email, but leave it alone on Canvas
  # for now. They can change it there if they want. We haven't implemented the ability for a name
  # change alone (email stays the same) to be synced. The reason to update it locally is so that our
  # comms are correct if we made a mistake and change it later.
  def run!
    Honeycomb.add_field('user.email', @user.email)
    Honeycomb.add_field('user.unconfirmed_email', @user.unconfirmed_email)
    Honeycomb.add_field('salesforce.contact.email', @salesforce_contact.email)

    if @user.unconfirmed_email&.downcase == @salesforce_contact.email.downcase
      Honeycomb.add_field('sync_from_salesforce_contact.email_changed', false)
      Honeycomb.add_field('sync_from_salesforce_contact.email_changed_details', 'Email change was already requested and reconfirmation email sent. Skipping.')
      return
    elsif @user.email.downcase == @salesforce_contact.email.downcase
      Honeycomb.add_field('sync_from_salesforce_contact.email_changed', false)
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
