# Open the class and prepend our module to intercept calls to :start_span so
# we can add tags to Sentry events.

require 'honeycomb_sentry_integration'
require 'honeycomb-beeline'
module Honeycomb
   class Client
     prepend HoneycombSentryIntegration
   end
end
