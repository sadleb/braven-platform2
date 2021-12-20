require 'sidekiq'
require 'sidekiq_unique_jobs'
require 'honeycomb_sidekiq_integration'

# Note: this is just the server configuration. It doesn't actually start the server.
# That's done using: bundle exec sidekiq
# (on a worker dyno in Heroku or in a background process in dev)
Sidekiq.configure_server do |config|
  config.redis = { ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }

  # See: https://github.com/mhenrixon/sidekiq-unique-jobs#add-the-middleware
  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end

  config.server_middleware do |chain|
    # This one has to be first so that it also wraps jobs that fail due
    # to unique locks and raise errors on_conflict
    chain.add Sidekiq::HoneycombMiddleware
    chain.add SidekiqUniqueJobs::Middleware::Server
  end
end

Sidekiq.configure_client do |config|
  config.redis = { ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end
end

# See: https://github.com/mhenrixon/sidekiq-unique-jobs#uniqueness
SidekiqUniqueJobs.configure do |config|
  config.enabled = !Rails.env.test?
  # Turn these on if you need to debug why a lock isn't working.
  # The info should be added in the sidekiq UI in the "Locks" tab
  #config.lock_info = true
  #config.debug_lua = true
end
