# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  HONEYCOMB_RUNNING_USER_EMAIL_FIELD = 'active_job.email'
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  include Sidekiq::Worker::Options
  sidekiq_options retry: false

  # Note: see lib/honeycomb_sidekiq_integration.rb for information about instrumentation.
  # All jobs run later using Sidekiq have a sidekiq.job root span and sidekiq.class field
end
