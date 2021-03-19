# frozen_string_literal: true

# Salesforce program sync to lms job
class SyncSalesforceProgramToLmsJob < ApplicationJob
  queue_as :default

  def perform(program_id, email)
    SyncPortalEnrollmentsForProgram.new(salesforce_program_id: program_id).run
    SyncSalesforceToLmsMailer.with(email: email).success_email.deliver_now
  end

  rescue_from(StandardError) do |exception|
    Rails.logger.error(exception)
    Honeycomb.add_field('error', exception.class.name)
    Honeycomb.add_field('error_detail', exception.message)
    SyncSalesforceToLmsMailer.with(email: arguments.second).failure_email.deliver_now
  end
end
