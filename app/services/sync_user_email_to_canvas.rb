# frozen_string_literal: true
require 'canvas_api'

# This service handles sync'ing the User.email to Canvas so that they are in sync
# and login works.
#
# Paths to handle:
# 1. Normal sign-up and confirmation. Email should match and this will be a NOOP,
#    BUT it could have been manually changed so make sure it matches and change if necessary.
# 2. Nightly 'Sync From Salesforce' detects an email inconsistency and sets it to the Salesforce
#    value generating a reconfirmation email. Old login continues to work until they confirm the new one.
# 3. Staff manually trigger a 'Sync From Salesforce' and the emails don't match.
# 4. Email changes on the Salesforce Contact record which triggers an update. Behavior as #2.
#
# Note: Doesn't handle the lower level Devise related stuff, like the token not matching or having already been consumed.
class SyncUserEmailToCanvas

  def initialize(user)
    @user = user
  end

  def run!
    Honeycomb.add_field('user.email', @user.email)

    @canvas_login = CanvasAPI.client.get_login(@user.canvas_user_id)
    @canvas_login_email = @canvas_login['unique_id']
    Honeycomb.add_field('canvas.user.email', @canvas_login_email)

    if @canvas_login_email.downcase != @user.email.downcase
      Honeycomb.add_field('confirm_user_account.email_matches', false)
      change_canvas_email()
    else
      Honeycomb.add_field('confirm_user_account.email_matches', true)
    end

    Honeycomb.add_field('confirm_user_account.success', true)
    Rails.logger.info("Finished account confirmation for #{@user.inspect}.")
  end

private


  # Login emails and the emails that Canvas sends Notifications to are completely separate.
  # We need to do both.
  def change_canvas_email()
    Honeycomb.start_span(name: 'confirm_user_account.change_canvas_email') do |span|
      skip_confirmation_email = true
      CanvasAPI.client.update_login(@canvas_login['id'], @user.email)
      CanvasAPI.client.create_user_email_channel(@user.canvas_user_id, @user.email, skip_confirmation_email)
      begin
        CanvasAPI.client.delete_user_email_channel(@user.canvas_user_id, @canvas_login_email)
      rescue RestClient::NotFound => e_ok
        # This shouldn't really happen, but if it does we don't care. The important
        # part is having the new login as a communication channel.
        Honeycomb.add_field('alert.confirm_user_account.missing_old_canvas_email_channel', true)
        Rails.logger.info("Skipping delete! There was no email communication channel for #{@canvas_login_email}")
      end
    end
  rescue RestClient::Exception => e
    Sentry.capture_exception(e)
    Honeycomb.add_field('alert.confirm_user_account.change_canvas_email_failed', true)
    Rails.logger.error("ERROR: Changing email from #{@canvas_login_email} to #{@user.email} failed.")
    raise
  end

end
