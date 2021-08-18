# frozen_string_literal: true

# Base application job
class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  include Sidekiq::Worker::Options
  sidekiq_options retry: false

  # By wrapping all of our jobs in a manual span like this instead of relying on the
  # auto-instrumentation we've configued in config/initializes/honeycomb, uncaught exceptions
  # now magically populate the root error and error_detail fields so we don't have to go digging
  # down into 'perform.active_job.exception' and 'perform.active_job.exception_object'
  around_perform do |job, block|
    Honeycomb.start_span(name: "#{job.class.name.underscore}.active_job") do |span|
      # The naming here is to stay consistent with the other auto-instrumented active_job fields
      span.add_field 'queue_name.active_job', job.queue_name
      block.call
    end
  end
end
