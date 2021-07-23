require_relative 'boot'

require 'rails/all'

require_relative '../lib/lti_rise360_proxy'
require_relative '../lib/honeycomb_trace_propagation'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Platform
  class Application < Rails::Application

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    # Determines whether forgery protection is added on ActionController:Base. This is false by default to
    # be backwards compatible with v5.2 and below who may have removed it from ApplicationController
    config.action_controller.default_protect_from_forgery = true

    # Allows us to serve Rise360 static files hosted on AWS S3 through our server avoiding browser cross-origin issues.
    config.middleware.use LtiRise360Proxy, backend: "https://#{Rails.application.secrets.aws_files_bucket}.s3.amazonaws.com"

    # Allows us to continue Honeycomb traces propagated from an external source, like client-side Javascript.
    # Note that this needs to come before Honeycomb::Rack::Middleware to work (but that's inserted after this runs).
    config.middleware.insert_after(ActionDispatch::RequestId, Honeycomb::TracePropagation::Middleware)

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Allow `bundle exec rake assets:precompile` without loading the whole rails app.
    # E.g. if we want to run in production mode locally.
    #config.assets.initialize_on_precompile=false

    # For the default AsyncAdapter for ActiveJob, change max_threads to 3 instead of
    # the number of cores since our Heroku dyno's have 8 cores and the database connection
    # pool hack in config/database.yml could push us to exhaust the 120 max DB connections
    # pretty easily if scale our dynos or run one-offs.
    # DB connections = dynos * connections per dyno
    #                = dynos * (workers per dyno * connections per worker)
    #                = dynos * (WEB_CONCURRENCY * (PUMA_MAX_THREADS + ASYNC_ADAPTER_MAX_THREADS))
    #                = dynos * (2*(5+3))
    #                = dynos * 16
    # This let's us have up to 7 dynos running at once. The 8th can exhaust the max DB connections.
    # TODO: replace this with a real queue_adapter in production and get rid of the database connection pool hack:
    # https://app.asana.com/0/1174274412967132/1200138491722566
    ASYNC_ADAPTER_MAX_THREADS = 3
    PUMA_MAX_THREADS = Integer(ENV.fetch("PUMA_MAX_THREADS") { 5 })
    config.active_job.queue_adapter = ActiveJob::QueueAdapters::AsyncAdapter.new \
      min_threads: 1,
      max_threads: ASYNC_ADAPTER_MAX_THREADS,
      idletime: 60.seconds
    end

end
