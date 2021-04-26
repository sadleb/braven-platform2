# frozen_string_literal: true
require 'canvas_api'

# Responsible for handling requests to sync Salesforce data to Platform
# and Canvas.
class SalesforceController < ApplicationController
  layout 'admin'

  # Disable putting everything inside a "salesforce" param. This controller doesn't represent a model.
  wrap_parameters false

  skip_before_action :verify_authenticity_token, only: [:update_contacts]

  def init_sync_from_salesforce_program
    authorize :SalesforceAuthorization
  end

  # Shows a list of participants that will get email notifications with instructions
  # for how to sign-up and create their Canvas account. Allows the staff member to
  # confirm the list before kicking off the actual sync
  def confirm_send_sign_up_emails
    authorize :SalesforceAuthorization
    @new_participants = get_participants_never_synced_before()
  end

  def sync_from_salesforce_program
    authorize :SalesforceAuthorization

    should_send_sign_up_emails = ActiveModel::Type::Boolean.new.cast(params[:send_sign_up_emails])

    if should_send_sign_up_emails && params[:not_confirmed]
      redirect_to salesforce_confirm_send_sign_up_emails_path(program_id: params[:program_id].strip, email: params[:email].strip)
      return
    end

    SyncFromSalesforceProgramJob.perform_later(params[:program_id].strip, params[:email].strip, should_send_sign_up_emails)
    redirect_to root_path, notice: 'The sync process was started. Watch out for an email'
  end

  # Sync's Contact information from Salesforce to both Platform and Canvas.
  # Currently, this is meant to handle changing an email in Salesforce and
  # having a Process Builder trigger in Salesforce call into this to sync that change.
  #
  # Note: the Salesforce side sends a list of Contacts b/c Salesforce's `InvocableMethod` annotation/interface
  # uses a list: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_InvocableMethod.htm
  # From Process Builder in Salesforce where we currently invoke it to call into this
  # endpoint, there can only be one Contact in the list. I left it as a list though so
  # that if we end up invoking it from elsewhere in Salesforce in the future, we don't
  # have to update the Apex class (BZ_SyncContactToCanvas.apxc) and we can just change this
  # code to handle batches.
  def update_contacts
    authorize :SalesforceAuthorization

    begin
      contact = params[:contacts].first

      @canvas_user_id = contact[:Canvas_Cloud_User_ID__c].to_i # Sent by SF as: 12345.0
      Honeycomb.add_field('user.canvas_user_id', @canvas_user_id)

      # Raise if not found so we don't change anything in Canvas.
      @user = User.find_by!(canvas_user_id: @canvas_user_id)

      @new_email = contact[:Email]
      # Note: we don't send these to Canvas. Rely on users do update their own names.
      @first_name = contact[:FirstName]
      @last_name = contact[:LastName]
      @salesforce_contact_id = contact[:Id]

      # Error out before making any changes if things are missing
      raise ArgumentError.new("Missing Email for: #{contact}") unless @new_email
      raise ArgumentError.new("Missing FirstName for: #{contact}") unless @first_name
      raise ArgumentError.new("Missing LastName for: #{contact}") unless @last_name

      @old_email = @user.canvas_login_email
      Honeycomb.add_field('user.email', @old_email)
      Honeycomb.add_field('salesforce.contact.email', @new_email)

      # Wait until everything succeeds before sending the confirmation notification
      @user.skip_confirmation_notification!

      # The most likely way this can fail is email conflicts. It's a unique column
      # Note that this doesn't actually set the `email` column. It set's the
      # `unconfirmed_email` column until they actually confirm.
      @user.update!(email: @new_email, first_name: @first_name, last_name: @last_name)
      Honeycomb.add_field('salesforce_controller.updated_platform_email', true)

      change_canvas_email() do |error|
        if error
          # Try to roll the local database update back if Canvas fails.
          @user.update(unconfirmed_email: nil)
          Honeycomb.add_field('salesforce_controller.updated_platform_email_rollback', true)
          Honeycomb.add_field('salesforce_controller.updated_platform_email', false)
        end
      end

      # Alright, everything worked. Send them the reconfirmation email so they are aware
      # their account changed and can activate it. This is also a safegaurd against staff
      # setting an email that someone doesn't actually control (e.g. something with a typo)
      # and then telling them to use it to login. The person must actually have access to
      # the email address for the account to be active and able to login.
      @user.send_confirmation_instructions

    rescue => e2
      Sentry.capture_exception(e2)
      Honeycomb.add_field('error', e2.class.name)
      Honeycomb.add_field('error_detail', e2.message)
      Honeycomb.add_field('alert.salesforce_controller.updated_contact_failed', true)
      Rails.logger.error(e2.message)
      SyncSalesforceContactToCanvasMailer.with(
        staff_email: params[:staff_email],
        first_name: @first_name,
        last_name: @last_name,
        new_email: @new_email,
        user_id: @user.id,
        canvas_user_id: @canvas_user_id,
        salesforce_contact_id: @salesforce_contact_id,
        exception: e2,
      ).failure_email.deliver_now
    end

    # No matter what, the response to SF is success. It calls this from a queued job and
    # you have to jump through hoops to be able to find any error messages on SF.
    # All error handling is done here in platform.
    respond_to do |format|
      format.json { head :no_content }
    end
  end

private

  # Login emails and the emails that Canvas sends Notifications to are completely separate.
  # We need to do both.
  def change_canvas_email()
    Honeycomb.start_span(name: 'salesforce_controller.change_canvas_email') do |span|
      CanvasAPI.client.change_user_login_email(@canvas_user_id, @new_email)
      CanvasAPI.client.create_user_email_channel(@canvas_user_id, @new_email)
      begin
        CanvasAPI.client.delete_user_email_channel(@canvas_user_id, @old_email)
      rescue RestClient::NotFound => e_ok
        # This shouldn't really happen, but if it does we don't care. The important
        # part is having the new login as a communication channel.
        Honeycomb.add_field('alert.salesforce_controller.missing_old_canvas_email_channel', true)
        Rails.logger.info("Skipping delete! There was no email communication channel for #{@old_email}")
      end
    end
  rescue RestClient::Exception => e
    Sentry.capture_exception(e)
    Honeycomb.add_field('alert.salesforce_controller.change_canvas_email_failed', true)
    Rails.logger.error("ERROR: Changing email from #{@old_email} to #{@new_email} failed.")
    yield(true)
    raise
  end

  def get_participants_never_synced_before
    participants = SalesforceAPI.client.find_participants_by(program_id: params[:program_id])
    participants.select { |p| p.status == 'Enrolled' && User.find_by(salesforce_id: p.contact_id).nil? }.compact
  end

end
