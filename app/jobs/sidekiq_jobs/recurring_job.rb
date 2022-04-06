# frozen_string_literal: true

# Base class for job's that are run on a recurring schedule (similar to
# a cron job or a rake task that uses Heroku Scheduler).
# These use the gem: https://github.com/moove-it/sidekiq-scheduler
#
# Go here to see the list of cron jobs running (and manage them a bit):
# https://platformweb/sidekiq/recurring-jobs
#
# Adding a new job:
# 1. Create a new class under app/jobs/sidekiq_jobs that subclasses this.
# 2. Define a perform() method that can take arguments
# 3. Make sure the args are simple JSON serializable datatypes.
#   a. See: https://github.com/mperham/sidekiq/wiki/The-Basics#client
# 4. Open config/sidekiq.yml and add a new entry under the :schedule key
# 5. Restart the server and go here to see that your job is scheduled:
#   https://platformweb/sidekiq/recurring-jobs
# 6. See here for the various ways you can schedule the job:
#   https://github.com/moove-it/sidekiq-scheduler#schedule-types
#
# A very common requirement for scheduled jobs is for them to be unique,
# meaning only one should be running at a time for a given set of parameters / args.
# We use this gem to provide that functionality:
# https://github.com/mhenrixon/sidekiq-unique-jobs
# See SyncSalesforceChangesJob#sidekiq_options for an example.
#
# IMPORTANT: if this is a unique job, you should prevent the sidekiq_options#lock_ttl
# to be less than the frequency of the recurring job. Otherwise, they can run in parallel
# and misleading logs about them being skipped when they really ran are sent by
# SidekiqUniqueJobs::OnConflict::LogHoneycomb
#
# Note: with the introduction of the sidekiq-unique-jobs functionality,
# we CANNOT use ActiveJob. Notice how this class subclasses SidekiqJob (which
# is a Sidekiq::Worker) instead of ApplicationJob (which is an ActiveRecord::Base).
# This limitation was a small note in the sidekiq-unique-jobs docs that I sort of
# ignored and lost nearly a day of troubleshooting until I realized that it really
# doesn't work even though it appears to on the surface.  The reason is b/c
# ActiveJobs executed using Sidekiq are put in a SidekiqAdapter::JobWrapper but
# sidekiq-unique-jobs relies on the actual job class from being passed to it so
# that it can determine the uniqueness of the job. If they ever change the
# following class to handle a SidekiqAdapter::JobWrapper passed as the `item` when
# getting the CLASS and LOCK_ARGS to determine the unique hash, then we may be
# able to start using ActiveJob for these:
# https://github.com/mhenrixon/sidekiq-unique-jobs/blob/main/lib/sidekiq_unique_jobs/lock_digest.rb#L60
class RecurringJob < SidekiqJob

  # Information about each recurring job's schedule.
  def self.job_schedules
    @job_schedules = SidekiqScheduler::JobPresenter.build_collection(Sidekiq.schedule!)
  end

  # Returns how often this job will run in seconds.
  # Currently only handles the `every` config option for a schedule.
  #
  # IMPORTANT: if the schedule is complete disabled using SIDEKIQ_SCHEDULER_ENABLED=false
  # this will return the last configured interval, not necessarily the currently configured
  # one and it won't actually be running at all on a recurring schedule.
  def interval
    RecurringJob.job_schedules.each do |schedule|
      if self.class.name == schedule['class']

        # You can disable a schedule through the UI, so just return -1 to represent
        # that it's not running
        return -1 unless schedule.enabled?

        every = schedule['every']
        raise RuntimeError, "config/sidekiq.yml missing 'every' config option for #{schedule['class']}" if every.nil?

        if every.is_a?(Array)
          # E.g. every: ['300s', 'first_in: '120s']
          return every[0].to_i
        else
          # E.g. every: '300s'
          return every.to_i
        end
      end
    end
    raise RuntimeError, "Cannot determine interval for #{self.class.name} in schedule: #{Sidekiq.get_schedule.inspect}"
  end
end
