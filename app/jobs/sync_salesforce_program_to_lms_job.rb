# frozen_string_literal: true

# Salesforce program sync to lms job
class SyncSalesforceProgramToLmsJob < ApplicationJob
  queue_as :default

  def perform(program_id, email)
    sync_service = SyncPortalEnrollmentsForProgram.new(salesforce_program_id: program_id)
    begin
      sync_service.run()
      SyncSalesforceToLmsMailer.with(email: email).success_email.deliver_now
    rescue => exception
      Rails.logger.error(exception)
      SyncSalesforceToLmsMailer.with(
        email: email,
        exception: exception,
        failed_participants: sync_service.failed_participants,
        total_participants_count: sync_service.count
      ).failure_email.deliver_now
      raise
    end
  end

end
