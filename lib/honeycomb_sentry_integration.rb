# frozen_string_literal: true
# Set up Sentry->Honeycomb integration.
require 'sentry-ruby'

# Our Honeycomb team name; be sure to change if using a different team.
HONEYCOMB_TEAM = 'braven'

# Prepend this module to Honeycomb::Client in order to add Honeycomb
# trace URLs to Sentry events.
# https://github.com/honeycombio/beeline-ruby/blob/main/lib/honeycomb/client.rb
module HoneycombSentryIntegration
  def start_span(name:, serialized_trace: nil, **fields)
    return super unless block_given?

    super do |span|
      Sentry.configure_scope do |scope|
        scope.set_tags({
          honeycomb: "https://ui.honeycomb.io/#{HONEYCOMB_TEAM}/datasets/#{@libhoney.dataset}/trace?trace_id=#{span&.trace&.id}",
        })
      end
      yield span
    end
  end
end
