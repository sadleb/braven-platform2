# frozen_string_literal: true
require 'salesforce_api'

# Responsible for handling requests to sync Salesforce data to Platform
# and Canvas.
class SalesforceController < ApplicationController
  layout 'admin'

  # Disable putting everything inside a "salesforce" param. This controller doesn't represent a model.
  wrap_parameters false

  skip_before_action :verify_authenticity_token, only: [:update_contacts]

  def init_sync_salesforce_program
    authorize :SalesforceAuthorization
  end

  def sync_salesforce_program
    authorize :SalesforceAuthorization

    should_force_zoom_update = ActiveModel::Type::Boolean.new.cast(params[:force_zoom_update])

    SyncSalesforceProgramJob.perform_later(params[:program_id].strip, params[:email].strip, should_force_zoom_update)
    redirect_to salesforce_sync_salesforce_program_path, notice: 'The sync process was started. Watch out for an email'
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

      # Note that the format of the JSON sent is defined in the BZ_SyncContactsToCanvas::SyncContactJson
      # class here: https://github.com/beyond-z/salesforce/blob/master/src/classes/BZ_SyncContactsToCanvas.apxc

      @canvas_user_id = contact[:CanvasUserId]
      Honeycomb.add_field_to_trace('canvas.user.id', @canvas_user_id.to_s)

      @new_email = contact[:Email]
      @first_name = contact[:FirstName]
      @last_name = contact[:LastName]
      @salesforce_contact_id = contact[:ContactId]
      Honeycomb.add_field_to_trace('salesforce.contact.id', @salesforce_contact_id)

      # Raise if not found so we don't change anything in Canvas.
      @user = User.find_by!(salesforce_id: @salesforce_contact_id)

      # Overwrite the trace's user information with user we're syncing, not the running user.
      @user.add_to_honeycomb_trace()

      # Error out before making any changes if things are missing
      raise ArgumentError.new("Missing CanvasUserId for: #{contact}") unless @canvas_user_id
      raise ArgumentError.new("Missing ContactId for: #{contact}") unless @salesforce_contact_id
      raise ArgumentError.new("Missing Email for: #{contact}") unless @new_email
      raise ArgumentError.new("Missing FirstName for: #{contact}") unless @first_name
      raise ArgumentError.new("Missing LastName for: #{contact}") unless @last_name

      SyncSalesforceContact.new(
        SalesforceAPI::SFContact.new(@salesforce_contact_id, @new_email, @first_name, @last_name),
        false
      ).run

    rescue => e2
      Sentry.capture_exception(e2)
      Honeycomb.add_field('error', e2.class.name)
      Honeycomb.add_field('error_detail', e2.message)
      Honeycomb.add_field('alert.salesforce_controller.updated_contact_failed', true)
      Rails.logger.error(e2.message)
      user_id = @user&.id || '<Unknown>' # we could have failed to find the user
      SyncSalesforceContactToCanvasMailer.with(
        staff_email: params[:staff_email],
        first_name: @first_name,
        last_name: @last_name,
        new_email: @new_email,
        user_id: user_id,
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

end
