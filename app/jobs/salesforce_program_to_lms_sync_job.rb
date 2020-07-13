# frozen_string_literal: true

# Salesforce program sync to lms job
class SalesforceProgramToLmsSyncJob < ApplicationJob
  queue_as :default

  def perform(program_id)
    SyncToLMS.new.for_program(program_id)
  end
end
