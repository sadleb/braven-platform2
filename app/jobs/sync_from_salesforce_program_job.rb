# frozen_string_literal: true

class SyncFromSalesforceProgramJob < ApplicationJob
  queue_as :default

  def perform(program_id, email, send_signup_emails = false)
    sync_service = SyncPortalEnrollmentsForProgram.new(salesforce_program_id: program_id, send_signup_emails: send_signup_emails)
    begin
      sync_service.run()
      SyncFromSalesforceProgramMailer.with(email: email).success_email.deliver_now
    rescue => exception
      Rails.logger.error(exception)
      SyncFromSalesforceProgramMailer.with(
        email: email,
        exception: exception,
        failed_participants: sync_service.failed_participants,
        total_participants_count: sync_service.count
      ).failure_email.deliver_now
      raise
    end
  end

end
