# frozen_string_literal: true

# Responsible for syncing a single Salesforce Program.
#
# Only one of these jobs for a given Program will be run at a time b/c of
# the sidekiq-unique-jobs settings below.
#
# Notes:
# 1). A Contact can be a Participant in multiple programs. This job handles that edge
#     case by recovering gracefully if two jobs try to create the same user and the
#     second one fails b/c of unique database constraints on the local User model.
# 2). The CanvasAPI won't throttle you if things are called serially. But if they are called
#     in parallel it's far more likely we'd get throttled and it would start throwing errors
#     that we'd need to handle / retry. Handle that if we start running into it.
#
# The automatic sync with default options runs on a recurring schedule using the
# SyncSalesforceChangesJob
#
# This job can also be run from the UI with extra options. In that case the email address
# of the person running it will be provided and we'll email the sync results.
class SyncSalesforceProgramJob < SidekiqJob

  # The runtime for a single job shouldn't exceed the SALESFORCE_SYNC_MAX_DURATION
  # below. If it does, that will allow a second job to start running. A job is
  # considered dead and the lock is released after this interval.
  #
  # This should be configured as the amount of time we want to let a sync job
  # run before it exits and let's the next sync job try again.
  # Don't set this too high b/c if a job crashes or the worker process restarts
  # and it doesn't release the lock, no other jobs can start until this time expires.
  #
  # Note: the longest sync with the old code was 52 minutes at the time of writing.
  # This was primarily b/c each CanvasAPI call was taking on the order of 400ms and
  # we were calling it for every Enrolled Participant regardless of whether there
  # were changes. The new sync logic won't call the API if there are no changes,
  # and uses an SIS Import, so the time is largely waiting on the import to finish.
  SALESFORCE_SYNC_MAX_DURATION = begin
    max_duration = Integer(ENV['SALESFORCE_SYNC_MAX_DURATION']) if ENV['SALESFORCE_SYNC_MAX_DURATION']
    max_duration ||= 10.minutes.to_i
  end

  # Release the lock after after this amount of time.
  #
  # This is REALLY important b/c if the server restarts or crashes while a lock
  # is held and it's not released, then all future jobs wouldn't run if there
  # was no lock_ttl (time to live) specified.
  def self.lock_ttl
    SALESFORCE_SYNC_MAX_DURATION
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
    lock_ttl: SyncSalesforceProgramJob.lock_ttl,
    # If another job has the lock, fail immediately using the on_conflict strategy below.
    lock_timeout: 0,
    # Just log and send to Honeycomb when a job is skipped b/c another job has the lock.
    # See here for more info on the on_conflict strategies:
    #   https://github.com/mhenrixon/sidekiq-unique-jobs#conflict-strategy
    # and here for our custom log_honeycomb strategy
    #   lib/honeycomb_sidekiq_integration.rb
    on_conflict: {
      client: :log_honeycomb,
      server: :log_honeycomb
    }
  )


  # IMPORTANT: if you move the position of the program_id argument, update the
  # lock_args method below to match.
  #
  # Note: don't use keyword args for Sidekiq jobs:
  # https://github.com/mperham/sidekiq/wiki/Best-Practices#1-make-your-job-parameters-small-and-simple
  def perform(program_id, email = nil, force_canvas_update=false, force_zoom_update = false)
    sync_service = nil
    Honeycomb.start_span(name: 'sync_salesforce_program_job.perform') do
      Honeycomb.add_field(ApplicationJob::HONEYCOMB_RUNNING_USER_EMAIL_FIELD, email)
      Honeycomb.add_field_to_trace('salesforce.program.id', program_id)

      program = HerokuConnect::Program.find_by(sfid: program_id)
      if program.nil?
        raise SyncSalesforceProgram::MissingProgramError.new(
          "Program ID: #{program_id} not found on Salesforce. Please enter a valid Program ID"
        )
      end

      sync_service = SyncSalesforceProgram.new(
        program,
        SALESFORCE_SYNC_MAX_DURATION,
        force_canvas_update,
        force_zoom_update
      )
      sync_service.run()

      SyncSalesforceProgramMailer.with(email: email).success_email.deliver_now if email.present?
    end
  rescue => e
    if email.present?
      SyncSalesforceProgramMailer.with(
        email: email,
        exception: e,
        failed_participants: sync_service.failed_participants,
        total_participants_count: sync_service.count
      ).failure_email.deliver_now
    end

    if e.is_a?(SyncSalesforceProgram::MissingCourseModelsError) && Rails.env.development?
      # This is expected in dev since each dev uses a different Sandbox Salesforce Program
      # for their local Courses. No need to create noise.
      Rails.logger.debug("Skipping sync for Program Id: #{program_id} in dev. Missing local Course models.")
      return
    else
      raise
    end
  end

  # Two jobs with the same program_id should be considered the same
  # regardless of the other run options.
  #
  # See here: https://github.com/mhenrixon/sidekiq-unique-jobs#finer-control-over-uniqueness
  def self.lock_args(args)
    [ args.first ]
  end

end
