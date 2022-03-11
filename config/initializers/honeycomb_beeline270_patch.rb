# Patch to partially revert the change introduced in v2.7.0 of the ruby beeline.
# Refs:
# * https://github.com/honeycombio/beeline-ruby/releases/tag/v2.7.0
# * https://github.com/honeycombio/beeline-ruby/pull/166
# * https://github.com/leviwilson/beeline-ruby/blob/ba5bc98f5abb336f85e4fd5d405d4f040e59a6d5/lib/honeycomb/integrations/active_support.rb
module Honeycomb
  module ActiveSupport
    module Configuration
      def default_handler
        @default_handler ||= lambda do |name, span, payload|
          payload.each do |key, value|
            # Make ActionController::Parameters parseable by libhoney.
            value = value.to_unsafe_hash if value.respond_to?(:to_unsafe_hash)
            span.add_field("#{name}.#{key}", value)
          end

          # If the notification event has recorded an exception, add the
          # Beeline's usual error fields to the span.
          # * Uses the 2-element array on :exception in the event payload
          #   to support Rails 4. If Rails 4 support is dropped, consider
          #   the :exception_object added in Rails 5.
          error, error_detail = payload[:exception]
          # START BRAVEN PATCH
          unless name == 'sql.active_record'
            # Don't copy `sql.active_record.exception` to `error`, because it
            # clutters up the data with noise from create_or_find_by queries
            # that raised and handled their own exception.
            span.add_field("error", error) if error
            span.add_field("error_detail", error_detail) if error_detail
          end
          # /END BRAVEN PATCH
        end
      end
    end
  end
end
