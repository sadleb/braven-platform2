# frozen_string_literal: true

# TODO: delete me and replace with SyncSalesforceChangesJob.
# In the future we could have a single scheduled job that kicks off
# a bunch of individual SyncSalesforceProgramJob's that run in parallel,
# but we need to handle changes to a Contact that is in multiple Programs
# and make sure that parallel jobs play nice.
# https://app.asana.com/0/1201131148207877/1201515686512764
class SyncSalesforceProgramJob < ApplicationJob
  queue_as :default

  def perform(program_id, email, force_zoom_update = false)
    Honeycomb.add_field(ApplicationJob::HONEYCOMB_RUNNING_USER_EMAIL_FIELD, email)
    sync_service = SyncSalesforceProgram.new(
      salesforce_program_id: program_id,
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
