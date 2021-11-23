# frozen_string_literal: true

class SyncSalesforceProgramJob < ApplicationJob
  queue_as :default

  def perform(program_id, email, send_signup_emails = false, force_zoom_update = false)
    Honeycomb.add_field(ApplicationJob::HONEYCOMB_RUNNING_USER_EMAIL_FIELD, email)
    sync_service = SyncSalesforceProgram.new(
      salesforce_program_id: program_id,
      send_signup_emails: send_signup_emails,
      force_zoom_update: force_zoom_update
    )
    begin
      sync_service.run()
      SyncSalesforceProgramMailer.with(email: email).success_email.deliver_now
    rescue => exception
      Rails.logger.error(exception)
      SyncSalesforceProgramMailer.with(
        email: email,
        exception: exception,
        failed_participants: sync_service.failed_participants,
        total_participants_count: sync_service.count
      ).failure_email.deliver_now
      raise
    end
  end

end
