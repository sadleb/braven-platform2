# frozen_string_literal: true

# Responsible for syncing information for ALL Participants in Current and
# Future Salesforce Programs to Platform, Canvas, Zoom, etc.
# Note: the Discord sync is separate.
#
# This is run as a scheduled job every ENV['SALESFORCE_SYNC_EVERY'] seconds.
#
# See RecurringJob and SidekiqJob for more info about how this differs from
# our normal ActiveJobs that are not scheduled.
class SyncSalesforceChangesJob  < RecurringJob

  sidekiq_options(
    queue: :low_priority,
  )

  def perform
    Honeycomb.start_span(name: 'sync_salesforce_changes_job.perform') do
      validate_config()

      # Kick off all program jobs and then exit. They run in parallel and each is
      # self contained. A second run of this job before one of them has finished will
      # simply queue up the program job which will skip and log unless
      # SALESFORCE_SYNC_MAX_DURATION has expired.
      HerokuConnect::Program.current_and_future_program_ids.each do |program_id|
        Rails.logger.debug("Kicking off SyncSalesforceProgramJob for #{program_id}")
        job_id = SyncSalesforceProgramJob.perform_async(program_id)
        Rails.logger.debug("  -> jid=#{job_id}")
      rescue => e
        # Continue trying to enqueue jobs for the other Programs.
        Sentry.capture_exception(e)
        Rails.logger.error("Error: there were sync failures for Program Id: #{program_id}. #{e.inspect}")
      end
    end
  end

  # Prevent misconfigured settings from allowing two jobs to run at the same time
  # for a single Program.
  def validate_config

    # If this isn't actually running on the Sidekiq server (aka the worker dyno),
    # it's most likely being run by an engineer from the console. Allow that.
    unless Sidekiq.server?
      Honeycomb.add_field('sync_salesforce_changes_job.validate_config.skipped', true)
      return
    end

    if interval > SyncSalesforceProgramJob.lock_ttl
      raise RuntimeError.new(
        "SALESFORCE_SYNC_EVERY set to run the sync every #{interval} seconds. " +
        "SALESFORCE_SYNC_MAX_DURATION is set to only hold the lock for #{SyncSalesforceProgramJob.lock_ttl} seconds. " +
        "This is wrong and could lead to edge cases where the same Program is being synced " +
        "by two jobs at once. Increase the max duration to be longer than the sync interval."
      )
    end
  end
end
