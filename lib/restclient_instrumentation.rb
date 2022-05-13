# frozen_string_literal: true

require 'logger'

# Prepend this module to RestClient::Request in order to instrument
# calls to `execute` with Honeycomb tracing and error logging.
#
# Note: all calls through RestClient boil down to executing this instance method.
module RestClientInstrumentation
  def execute &block
    ret_val = nil

    # Use Rails.logger if present, otherwise make our own.
    if defined?(Rails) && Rails.respond_to?(:logger)
      logger = Rails.logger
    else
      logger = Logger.new(STDOUT)
    end

    # Go down the stack looking for the first file not in the restclient gem to get
    # the API file calling this. Once that's found, look for the next file to get
    # the file calling that API. Add this info to Honeycomb to help manage alerts
    # and troubleshoot API errors.
    calling_location = nil
    parent_calling_location = nil
    caller_locations(2,10).each do |cl| # 2nd index (direct caller) through 10th arbitrarily
      if calling_location.nil?
        calling_location = cl if !cl.path.include?('restclient')
      elsif parent_calling_location.nil?
        if cl.path != calling_location.path
          parent_calling_location = cl
          break
        else
          # keep updating the caller to the deepest stackframe in that file
          # so we get the actual method being called in that file, not the helper
          # get/put/patch or retry_timeut stuff
          calling_location = cl
        end
      end
    end
    calling_class = File.basename(calling_location.path, '.rb').camelize
    parent_calling_class = File.basename(parent_calling_location.path, '.rb').camelize if parent_calling_location

    # I'm trying to mimic what normal Rails request's send:
    # https://guides.rubyonrails.org/active_support_instrumentation.html#process-action-action-controller
    Honeycomb.start_span(name: "restclient.#{method}") do |span|
      # Note: if you change these fields below, make sure and update the place in
      # lib/discord_bot.rb that overrides/fixes it for discord if necessary. Search for
      # 'restclient.class' in there.
      span.add_field('restclient.class', calling_class)
      span.add_field('restclient.method', calling_location.base_label)
      span.add_field('restclient.parent_class', parent_calling_class)
      span.add_field('restclient.parent_method', parent_calling_location&.base_label)
      span.add_field('restclient.timestamp', DateTime.now)
      span.add_field('restclient.request.method', method)
      span.add_field('restclient.request.url', redacted_url) # Strips out password if it's in there.
      span.add_field('restclient.request.header', processed_headers.dup)
      begin
        ret_val = super(&block)
        span.add_field('restclient.response.status_code', ret_val.code)
      rescue RestClient::Exception => e
        logger.error("{\"Error\":\"#{e.message}\"}")
        error_response = e.http_body
        logger.error(error_response)
        span.add_field('restclient.response.status_code', e.http_code)
        span.add_field('restclient.response.body', error_response)
        span.add_field('restclient.response.headers', e.response&.headers)

        if e.is_a?(RestClient::BadRequest) and error_response =~ /JWS signature invalid/
          logger.error('TROUBLESHOOTING HINT: Copy/pasta the "Public JWK URL" from the Developer Key ' \
                             'in Canvas into the browser and make sure it returns a valid list of keys.')
        end

        raise
      end
    end

    ret_val
  end
end
