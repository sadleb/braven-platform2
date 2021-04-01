# frozen_string_literal: true

# Salesforce program sync to lms job
class SyncSalesforceProgramToLmsJob < ApplicationJob
  queue_as :default

  def perform(program_id, email)
    SyncPortalEnrollmentsForProgram.new(salesforce_program_id: program_id).run
    SyncSalesforceToLmsMailer.with(email: email).success_email.deliver_now
  rescue => exception
    Rails.logger.error(exception)
    SyncSalesforceToLmsMailer.with(email: email).failure_email.deliver_now
    raise
  end

end
