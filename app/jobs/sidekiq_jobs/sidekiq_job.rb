# frozen_string_literal: true

# Base class for job's that are plain old Sidekiq::Worker's and not
# ActiveJob's.
#
# Sentry and Honeycomb are integrated with these jobs using
# the sentry-sidekiq gem and our custom Sidekiq::HoneycombMiddleware
# module in honeycomb_sidekiq_integration.rb.
# The root Honeycomb span for all Sidekiq jobs is: name=sidekiq.job
# and the sidekiq.class field holds the actual class name.
#
# Right now, the main use-case is for UniqueSidekiqJob's which can't
# be ActiveJob's. See that class for more info.
#
# See here for why we named it SidekiqJob and not SidekiqWorker:
# https://github.com/mperham/sidekiq/wiki/Best-Practices#4-use-precise-terminology
class SidekiqJob
  include Sidekiq::Worker

  sidekiq_options retry: false

end
