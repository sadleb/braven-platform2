# frozen_string_literal: true

# Used for filtering out the parameters and data that you don't want shown in the logs,
# such as passwords or credit card numbers or the state param (which is like a password).
class FilterLogging

  FILTERED = '[FILTERED]'
  FILTERED_STATE_QUERY_PARAM = "state=#{FILTERED}"
  FILTERED_AUTH_QUERY_PARAM = "auth=#{FILTERED}"

  # These are the parameters where the entire value should be filtered out.
  FILTER_ENTIRE_ATTRIBUTE_NAMES = [
    'state',
    'auth',
    'password',
    'password_confirmation',
    'encrypted_password',
    'reset_password_token',
    'linked_in_access_token',
    'confirmation_token',
    'ticket',
    'lt', # stands for login ticket. See cas_controller
    'pgt', # stand for proxy granting ticket. See cas_controller
  ]

  MODELS_TO_FILTER = {
    'LtiLaunch' => ['state', 'id_token_payload'],
    'User' => ['encrypted_password', 'reset_password_token', 'linked_in_access_token', 'confirmation_token'],
    'RubyCAS::Server::Core::Tickets::LoginTicket' => ['ticket'],
    'RubyCAS::Server::Core::Tickets::ProxyGrantingTicket' => ['ticket'],
    'RubyCAS::Server::Core::Tickets::ServiceTicket' => ['ticket'],
    'RubyCAS::Server::Core::Tickets::TicketGrantingTicket' => ['ticket'],
    'AccessToken' => ['key'],
  }

  def self.is_enabled?
    # Filter sensitive data in all environments so that it's more likely we catch something slipping through
    true
  end

  # Returns a lambda function meant to be used with Rails.application.config.filter_parameters
  # or ActiveSupport::ParameterFilter. It is responsible for returning the filtered value of a
  # parameter if it contains sensitive data.
  def self.filter_parameters
    return @filter_parameters_lambda if @filter_parameters_lambda

    @filter_parameters_lambda = lambda do |param_name, value|
      return if value.blank?

      # Note: we have to alter the strings in place because we don't have access to
      # the hash to update the key's value

      if FILTER_ENTIRE_ATTRIBUTE_NAMES.include?(param_name)
        value.clear()
        value.insert(0, FILTERED)

      elsif param_name == 'url' || param_name == 'u' || param_name == 'pgu'
        value.gsub!(/state\=([^&]+)/, FILTERED_STATE_QUERY_PARAM)
        value.gsub!(/auth\=([^&]+)/, FILTERED_AUTH_QUERY_PARAM)

      elsif param_name == 'restiming'
        value.gsub!(/state\=([^"&]+)/, FILTERED_STATE_QUERY_PARAM)
        value.gsub!(/auth\=([^"&]+)/, FILTERED_AUTH_QUERY_PARAM)

      end
    end
  end

  # Filters sensitive values out of ActiveRecord SQL logging
  # Returns the filtered type_casted_binds array only if filtering
  # happened, else nil
  def self.filter_sql(log_name, binds, type_casted_binds_lambda)
    return nil unless FilterLogging.is_enabled?
    return nil if log_name.blank?

    filtered_type_casted_binds = nil

    # log_name will be something like "LtiLuanch Create" or "User Load"
    # It's always the model name followed by the action
    MODELS_TO_FILTER.each do |model_name, attributes_to_filter|
      if log_name.start_with?(model_name)
        binds.each_with_index do |bind, i|
          if attributes_to_filter.include?(bind.name) && bind.value.present?
            # Don't mess with the underlying objects which are used outside of just logging
            filtered_type_casted_binds = type_casted_binds_lambda.call().deep_dup unless filtered_type_casted_binds
            filtered_type_casted_binds[i] = FILTERED
          end
        end
      end
    end

    filtered_type_casted_binds
  end

  # Filters out sensitive information from the payloads sent to Honeycomb
  # using the above Rails.application.config.filter_parameters Proc.
  # See: https://docs.honeycomb.io/getting-data-in/ruby/beeline/#rails
  #
  # This just takes every Honeycomb field we know of that can have the state/password/etc
  # in it and runs the appropriate regex/filtering logic above by translating the Honeycomb
  # field to the corrseponding controller param that holds the sensitive data in the same
  # or similar format.
  def self.filter_honeycomb_data(fields)
    return unless FilterLogging.is_enabled?

    parameter_filter = FilterLogging.parameter_filter

    if fields['name'] == 'http_request'
      if fields.has_key?('request.query_string')
        fields['request.query_string'] = parameter_filter.filter_param('url', fields['request.query_string'])
      end
    end

    # These are values coming from HoneycombJsController generated spans
    # from Boomerang payloads.
    if fields['name'].start_with?('javascript')
      if fields.has_key?('request.query_string')
        fields['request.query_string'] = parameter_filter.filter_param('url', fields['request.query_string'])
      end
      if fields.has_key?('pgu')
        fields['pgu'] = parameter_filter.filter_param('pgu', fields['pgu'])
      end
      if fields.has_key?('u')
        fields['u'] = parameter_filter.filter_param('u', fields['u'])
      end
      if fields.has_key?('restiming')
        fields['restiming'] = parameter_filter.filter_param('restiming', fields['restiming'])
      end
      if fields.has_key?('state')
        fields['state'] = parameter_filter.filter_param('state', fields['state'])
      end
    end

    # RestClient
    if fields['name'].start_with?('restclient')
      if fields.has_key?('restclient.headers') && fields['restclient.headers']['Authorization']
        fields['restclient.headers']['Authorization'] = FILTERED
      end
    end

    # Note: ideally we would filter these at the source like we do for SQL logging so that we don't have to duplicate,
    # in the Sentry method, but this method is where it comes from and it looked dangerouls to try and override that
    # in a maintainable way to filter before sending the ActiveRecord::Notification:
    # https://github.com/rails/rails/blob/096719ce2a378ecbf7f07a2e586bd9ffd75e37b9/actionpack/lib/action_controller/metal/instrumentation.rb#L31
    if fields['name'] == 'process_action.action_controller'
      if fields.has_key?('process_action.action_controller.params')
        fields['process_action.action_controller.params'] = parameter_filter.filter_param('url', fields['process_action.action_controller.params'])
      end
      if fields.has_key?('process_action.action_controller.path')
        fields['process_action.action_controller.path'] = parameter_filter.filter_param('url', fields['process_action.action_controller.path'])
      end
    end

    # Note: the SQL logs are filtered at the source. See core_ext/postgresql_adapter.rb and
    # https://github.com/honeycombio/beeline-ruby/blob/585992c1abdc8143ef617b038a5ae87c65a0f428/lib/honeycomb/integrations/active_support.rb

  rescue => e
    Rails.logger.error(e)
    Sentry.capture_exception(e)
  ensure
    return fields
  end

  # Filters out sensitive information from the payloads sent to Sentry
  #
  # See: https://docs.sentry.io/platforms/ruby/configuration/filtering/
  def self.filter_sentry_data(event, hint)
    return unless FilterLogging.is_enabled?

    parameter_filter = FilterLogging.parameter_filter

    # NOTE1: if you have config.async configured, the event here will be a Hash instead of an Event object
    # This was written for an Event object so if you change it to async, this method needs to be updated:
    # https://github.com/getsentry/sentry-ruby/blob/master/sentry-ruby/lib/sentry/event.rb

    # NOTE2: the SQL statements in the breadcrumbs are filtered at the source. See core_ext/postgresql_adapter.rb
    # and https://github.com/getsentry/sentry-ruby/blob/master/sentry-rails/lib/sentry/rails/breadcrumb/active_support_logger.rb

    event.request.cookies = event.request.cookies.except('_platform_session')
    event.request.query_string = parameter_filter.filter_param('url', event.request.query_string)
    event.request.headers['Referer'] = parameter_filter.filter_param('url', event.request.headers['Referer'])
    event.breadcrumbs = FilterLogging.filter_sentry_breadcrumbs(event.breadcrumbs.to_hash)

  rescue => e
    Rails.logger.error(e)
    Honeycomb.add_field('sentry.error', e)
  ensure
    return event
  end

  # NOTE: I tried using the before_breadcrumb hook, similar to before_send but it wasn't being called.
  # If you ever figure out why or they fix the big, it may be simpler to use that hook to filter each
  # breadcrumb as they're added vs processing the whole hash
  def self.filter_sentry_breadcrumbs(breadcrumbs)
    parameter_filter = FilterLogging.parameter_filter

    breadcrumbs[:values].each { |bc|
      if bc[:category] == 'start_processing.action_controller' || bc[:category] == 'process_action.action_controller'
        bc[:data]['path'] = parameter_filter.filter_param('url', bc[:data]['path'])
      end
    }

    breadcrumbs
  end

  def self.parameter_filter
    return @parameter_filter if @parameter_filter
    @parameter_filter = ActiveSupport::ParameterFilter.new([FilterLogging.filter_parameters])
  end
end
