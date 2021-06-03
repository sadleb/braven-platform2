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
# 5. Staff admin or engineer accidentally changes Canvas login email through UI or API making them out of sync
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
      Honeycomb.add_field('sync_user_email_to_canvas.email_matches', false)
      change_canvas_email()
    else
      Honeycomb.add_field('sync_user_email_to_canvas.email_matches', true)
    end

    Honeycomb.add_field('sync_user_email_to_canvas.success', true)
  end

private


  # Login emails and the emails that Canvas sends Notifications to are completely separate.
  # We need to do both.
  def change_canvas_email()
    Honeycomb.start_span(name: 'sync_user_email_to_canvas.change_canvas_email') do |span|
      skip_confirmation_email = true
      CanvasAPI.client.update_login(@canvas_login['id'], @user.email)

      comm_channels = CanvasAPI.client.get_user_communication_channels(@user.canvas_user_id)

      unless CanvasAPI.client.get_user_email_channel(@user.canvas_user_id, @user.email, comm_channels).present?
        CanvasAPI.client.create_user_email_channel(@user.canvas_user_id, @user.email, skip_confirmation_email)
      end

      if CanvasAPI.client.get_user_email_channel(@user.canvas_user_id, @canvas_login_email, comm_channels).present?
        CanvasAPI.client.delete_user_email_channel(@user.canvas_user_id, @canvas_login_email)
      end
    end
    Rails.logger.info("Done changing Canvas login email from #{@canvas_login_email} to #{@user.email}.")
  rescue RestClient::Exception => e
    Sentry.capture_exception(e)
    Honeycomb.add_field('alert.sync_user_email_to_canvas.change_canvas_email_failed', true)
    Rails.logger.error("ERROR: Changing email from #{@canvas_login_email} to #{@user.email} failed.")
    raise
  end

end
