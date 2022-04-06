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

    # Haven't hooked this up to the UI yet b/c we don't know if we'll really need it until we
    # start to use the new SIS Import based sync and see what problems can arise.
    should_force_canvas_update = false

    SyncSalesforceProgramJob.perform_async(
      params[:program_id].strip,
      params[:email].strip,
      should_force_canvas_update,
      should_force_zoom_update
    )

    redirect_to salesforce_sync_salesforce_program_path, notice: 'The sync process was started. Watch out for an email'
  end

end
