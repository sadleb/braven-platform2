# frozen_string_literal: true

# Responsible for syncing information for ALL Participants in Current and
# Future Salesforce Programs to Platform, Canvas, Zoom, etc.
# Note: the Discord sync is separate.
#
# This is run as a scheduled job every ENV['SALESFORCE_SYNC_EVERY'] seconds.
# Only one of these jobs can be run at a time and shouldn't exceed the
# SALESFORCE_SYNC_MAX_DURATION.
#
# See RecurringJob and SidekiqJob for more info about how this differs from
# our normal ActiveJobs that are not scheduled.
class SyncSalesforceChangesJob  < RecurringJob

  # Time duration in seconds before a sync job is considered dead and the lock
  # should be available for another job to run. This is REALLY important b/c
  # if the server restarts or crashes while a lock is held and it's not released,
  # then all future jobs wouldn't run if there was no lock_ttl (time to live) specified.
  #
  # This should be configured as the the maximum amount of time that we expect a sync to
  # take in the worst case. If we set it lower than an actual sync run, we'll end up
  # with two syncs running at once which could / would duplicate work.
  # Note: the longest sync with the old code was 52 minutes at the time of writing.
  # This was primarily b/c each CanvasAPI call was taking on the order of 400ms and
  # we were calling it for every Enrolled Participant regardless of whether there
  # were changes. The new sync logic won't call the API if there are no changes,
  # so we don't expect the max to be anywhere near that high. I'm arbitrarily
  # choosing 15 min for now and we should tune this once the new sync code is
  # live and we gather data.
  SALESFORCE_SYNC_MAX_DURATION = begin
    max_duration = Integer(ENV['SALESFORCE_SYNC_MAX_DURATION']) if ENV['SALESFORCE_SYNC_MAX_DURATION']
    max_duration ||= 15.minutes.to_i
  end

  # Ensure that only a single one of these jobs can be executing at once across
  # all dynos / workers / sidekiq servers.
  # For more info, see: https://github.com/mhenrixon/sidekiq-unique-jobs
  sidekiq_options(
    # This isn't time sensitive, so don't have it block things like sending email
    # or grading a module since end-users are waiting on those directly.
    queue: :low_priority,
    # Only allow one of these to get the lock while the other is executing.
    # See here for the locking options: https://github.com/mhenrixon/sidekiq-unique-jobs#locks
    #
    # Note: there seems to be a bug with the :until_and_while_executing
    # strategy. It's a combination of :until_executing and :while_executing but the
    # :while_executing lock (with a :RUN suffix in the sidekiq dashboard)
    # never gets created so the job only runs once b/c the overall lock is never released.
    # The :while_executing strategy should be good enough. We don't care if it gets enqueued
    # as much as we do about it not actually running.
    lock: :while_executing,
    lock_prefix: 'sync',
    # Once a lock is gotten, expire it after this time interval.
    lock_ttl: SALESFORCE_SYNC_MAX_DURATION,
    # If another job has the lock, fail immediately using the on_conflict strategy below.
    lock_timeout: 0,
    # Just log when a job is skipped b/c another job has the lock. It'll just run
    # next time its scheduled.
    # See here for more info on the on_conflict strategies:
    # https://github.com/mhenrixon/sidekiq-unique-jobs#conflict-strategy
    on_conflict: {
      client: :log,
      server: :log
    }
  )

  def perform
    # TODO: switch this to the real sync once we implement it.
    # Add comment about how ideally, each program would be its own job so they could all
    # sync concurrently See SyncSalesforceProgramJob for why that's some work.
    # We'll just process them all serially here.
    ParticipantSyncInfo.run_sync_poc
  end

end
