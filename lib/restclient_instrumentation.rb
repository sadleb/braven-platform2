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

    # Go up the stack looking for the first file not in the restclient gem
    # (starting at caller of this, aka the 2nd index, and searching a max of 5 levels)
    calling_file_path = caller_locations(2,5).find {|cl| !cl.path.include?('restclient')}.path
    calling_class = File.basename(calling_file_path, '.rb').camelize

    # I'm trying to mimic what normal Rails request's send:
    # https://guides.rubyonrails.org/active_support_instrumentation.html#process-action-action-controller
    Honeycomb.start_span(name: "restclient.#{method}") do |span|
      span.add_field('restclient.class_name', calling_class)
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
