# frozen_string_literal: true

# Salesforce program sync to lms job
class SalesforceProgramToLmsSyncJob < ApplicationJob
  queue_as :default

  def perform(program_id, email)
    ProgramPortalEnrollments.new(salesforce_program_id: program_id).run
    SalesforceToLmsSyncMailer.with(email: email).success_email.deliver_now
  end

  rescue_from(StandardError) do |_exception|
    SalesforceToLmsSyncMailer.with(email: arguments.second).failure_email.deliver_now
  end
end
