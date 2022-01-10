require 'honeycomb-beeline'
require 'sidekiq_jobs/sidekiq_job'
require 'sidekiq_jobs/recurring_job'
require 'active_job/queue_adapters/sidekiq_adapter'

# Taken from here: https://github.com/honeycombio/beeline-ruby/issues/29
# and modified to handle ActiveJob workers too.
module Sidekiq

  # Captures Sidekiq logging for Honeycomb
  class HoneycombMiddleware

    # See here for more info about custom Sidekiq:Middleware
    # https://www.rubydoc.info/github/mperham/sidekiq/Sidekiq/Middleware
    #
    # @param [Object] worker the worker instance
    # @param [Hash] job the full job payload
    #   * @see https://github.com/mperham/sidekiq/wiki/Job-Format
    # @param [String] queue the name of the queue the job was pulled from
    # @yield the next middleware in the chain or worker `perform` method
    # @return [Void]
    def call(worker, job, queue) # rubocop:disable MethodLength

      # This is mostly for dev in case you don't configure Honeycomb
      if Honeycomb.client.nil?
        yield
        return
      end

      # Note: for ActiveJobs there is auto-instrumentation configured in config/initializers/honeycomb.rb
      # For non-ActiveJobs that subclass our SidekiqJob base class there isn't auto-instrumentation b/c
      # sidekiq doesn't publish any ActiveSupport::Notification events. Either way, by wrapping all of
      # jobs in a manual span like this instead of relying on auto-instrumentation, uncaught Exceptions
      # now magically populate the root error and error_detail fields so we don't have to go digging
      # down into 'perform.active_job.exception' and 'perform.active_job.exception_object' fields.
      Honeycomb.start_span(name: 'sidekiq.job') do |span|
        class_name = worker.class.name
        job_args = job['args']

        # For ActiveJob, these are wrapped in a ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper
        # The job['args'] actually has one arg with all the details in a hash.
        # See https://github.com/mperham/sidekiq/wiki/Job-Format
        if worker.is_a?(ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper)
          job_details = job['args'].first
          class_name = job_details['job_class']
          job_args = job_details['arguments']
          span.add_field('sidekiq.active_job.id', job_details['job_id']) # different from job['jid']
          span.add_field('sidekiq.job_type', 'active_job')
        elsif worker.is_a?(RecurringJob)
          span.add_field('sidekiq.job_type', 'recurring_job')
        else
          span.add_field('sidekiq.job_type', 'sidekiq_job')
        end

        span.add_field('sidekiq.class', class_name)
        span.add_field('sidekiq.args', job_args)
        span.add_field('sidekiq.queue', queue)
        span.add_field('sidekiq.jid', job['jid'])
        span.add_field('sidekiq.retry', job['retry'])
        span.add_field('sidekiq.retry_count', job['retry_count'])
        begin
          yield
          span.add_field('sidekiq.result', 'success')
        rescue => e
          span.add_field('sidekiq.result', 'error')
          span.add_field('sidekiq.error', e&.message)
          raise
        end
      end
    end

  end # HoneycombMiddleware
end

module SidekiqUniqueJobs
  module OnConflict

    # Strategy to send information about conflict to Honeycomb.
    # Extends this built-in strategy:
    # https://github.com/mhenrixon/sidekiq-unique-jobs/blob/f09d41b818286ed5549ac90ccc2ea386be9b5ca4/lib/sidekiq_unique_jobs/on_conflict/log.rb
    class LogHoneycomb < Log
      def call
        super
        Honeycomb.add_field('sidekiq.unique_jobs.conflict?', true)
        Honeycomb.add_field('sidekiq.unique_jobs.conflict.skip_reason',
          "Skipping job with `sidekiq.jid=#{item[JID]}` because lock_digest: (#{item[LOCK_DIGEST]}) already exists"
        )
      end
    end

  end
end
