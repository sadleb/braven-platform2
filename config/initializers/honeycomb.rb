require 'filter_logging'

Honeycomb.configure do |config|
  config.write_key = Rails.application.secrets.honeycomb_write_key
  config.dataset = Rails.application.secrets.honeycomb_dataset
  config.presend_hook do |fields|
    FilterLogging.filter_honeycomb_data(fields)
  end
  config.notification_events = %w[
    sql.active_record
    render_template.action_view
    render_partial.action_view
    render_collection.action_view
    process_action.action_controller
    send_file.action_controller
    send_data.action_controller
    deliver.action_mailer
    perform.active_job
    perform_start.active_job
    enqueue_at.active_job
    retry_stopped.active_job
    discard.active_job
    enqueue_retry.active_job
  ].freeze
  # Turn this on if you want to see some craziness
  # config.debug = true
end


require 'honeycomb_sentry_integration'
require 'honeycomb_braven'
require 'honeycomb-beeline'

module Honeycomb
  # Extend Honeycomb so that we can add things like
  # Honeycomb.send_alert() to standardize our instrumentation.
  extend HoneycombBraven

  # Open the class and prepend our module to intercept calls to :start_span so
  # we can add tags to Sentry events.
  class Client
    prepend HoneycombSentryIntegration
  end
end
