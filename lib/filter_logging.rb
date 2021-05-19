# frozen_string_literal: true

# Used for filtering out the parameters and data that you don't want shown in the logs,
# such as passwords or credit card numbers or the state param (which is like a password).
#
# IMPORTANT NOTE: if you add a parameter in this file, go to https://papertrailapp.com/account/settings
# click "Filter logs", and add it there too. We can't control the heroku/router logging
# and it sends query params in GET requests, so we just tell Papertrail to drop logs with
# those params. It's the filter that looks like: heroku\/router.*(state=|auth=|...)
class FilterLogging

  FILTERED = '[FILTERED]'
  FILTERED_STATE_QUERY_PARAM = "state=#{FILTERED}"
  FILTERED_STATE_QUERY_PARAM_ENCODED = "state%3D#{FILTERED}"
  FILTERED_AUTH_QUERY_PARAM = "auth=#{FILTERED}"
  FILTERED_AUTH_QUERY_PARAM_ENCODED = "auth%3D#{FILTERED}"
  FILTERED_TICKET_QUERY_PARAM = "ticket=#{FILTERED}"
  FILTERED_RESET_PASSWORD_TOKEN_QUERY_PARAM = "reset_password_token=#{FILTERED}"
  FILTERED_CONFIRMATION_TOKEN_QUERY_PARAM = "confirmation_token=#{FILTERED}"
  FILTERED_SIGNUP_TOKEN_QUERY_PARAM = "signup_token=#{FILTERED}"

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
    'signup_token',
    'ticket',
    'lt', # stands for login ticket. See cas_controller
    'pgt', # stand for proxy granting ticket. See cas_controller
  ]

  MODELS_TO_FILTER = {
    'LtiLaunch' => ['state', 'id_token_payload'],
    'User' => ['encrypted_password', 'reset_password_token', 'linked_in_access_token', 'confirmation_token', 'signup_token'],
    'RubyCAS::Server::Core::Tickets::LoginTicket' => ['ticket'],
    'RubyCAS::Server::Core::Tickets::ProxyGrantingTicket' => ['ticket'],
    'RubyCAS::Server::Core::Tickets::ServiceTicket' => ['ticket'],
    'RubyCAS::Server::Core::Tickets::TicketGrantingTicket' => ['ticket'],
    'AccessToken' => ['key'],
  }

  BOOMERANG_FIELD_PREFIX = 'js.boomerang'
  FILTER_BOOMERANG_FIELDS = [
    'pgu',
    'u',
    'restiming',
    'state',
    'error_detail', # Google Analytics puts the URL in the error_detail on failures
  ]

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

      elsif param_name == 'url' || param_name == 'u' || param_name == 'pgu' || param_name == 'restiming' || param_name == 'error_detail'
        value.gsub!(/state\=([^&" ]+)/, FILTERED_STATE_QUERY_PARAM)
        value.gsub!(/state%3D([^&" ]+)/, FILTERED_STATE_QUERY_PARAM_ENCODED)
        value.gsub!(/auth\=([^&" ]+)/, FILTERED_AUTH_QUERY_PARAM)
        value.gsub!(/auth%3D([^&" ]+)/, FILTERED_AUTH_QUERY_PARAM_ENCODED)
        value.gsub!(/ticket\=([^&" ]+)/, FILTERED_TICKET_QUERY_PARAM)
        value.gsub!(/reset_password_token=([^&" ]+)/, FILTERED_RESET_PASSWORD_TOKEN_QUERY_PARAM)
        value.gsub!(/confirmation_token=([^&" ]+)/, FILTERED_CONFIRMATION_TOKEN_QUERY_PARAM)
        value.gsub!(/signup_token=([^&" ]+)/, FILTERED_SIGNUP_TOKEN_QUERY_PARAM)
      end

      value
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
          if bind.respond_to?(:name) && attributes_to_filter.include?(bind.name) && bind.value.present?
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
    if fields['name'].start_with?('js.')
      if fields.has_key?("#{BOOMERANG_FIELD_PREFIX}.request.query_string")
        fields["#{BOOMERANG_FIELD_PREFIX}.request.query_string"] =
          parameter_filter.filter_param('url', fields["#{BOOMERANG_FIELD_PREFIX}.request.query_string"])
      end
      FILTER_BOOMERANG_FIELDS.each do |field_name|
        if fields.has_key?("#{BOOMERANG_FIELD_PREFIX}.#{field_name}")
          fields["#{BOOMERANG_FIELD_PREFIX}.#{field_name}"] =
            parameter_filter.filter_param("#{field_name}", fields["#{BOOMERANG_FIELD_PREFIX}.#{field_name}"])
        end
      end
    end

    # RestClient
    if fields['name'].start_with?('restclient')
      if fields.has_key?('restclient.request.header') && fields['restclient.request.header']['Authorization']
        fields['restclient.request.header']['Authorization'] = FILTERED
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

    # Don't send the entire file contents of S3 uploads.
    # Honeycomb drops events larger than a certain size, and we end up with missing spans.
    if fields.has_key?('aws.params.body')
      fields.delete('aws.params.body')
    end

    # Don't send email bodies from ActionMailer.
    # These often include sensitive information like tokens, and are hard to reliably
    # filter, since they're MIME-encoded.
    if fields.has_key?('deliver.action_mailer.mail')
      fields.delete('deliver.action_mailer.mail')
    end

    # Rewrite field names that are automatically added by the beeline's Warden
    # integration. They show up in the root namespace, which we don't want.
    # See https://github.com/honeycombio/beeline-ruby/blob/585992c1abdc8143ef617b038a5ae87c65a0f428/lib/honeycomb/integrations/warden.rb#L6
    warden_fields = Honeycomb::Warden::COMMON_USER_FIELDS.map { |f| "user.#{f}" }
    warden_fields.each do |field|
      fields["app.#{field}"] = fields.delete(field) if fields.has_key?(field)
    end

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

    event = event.to_hash

    cookies = event[:request][:cookies]
    event[:request][:cookies] = cookies.except('_platform_session') if cookies

    query_string = event[:request][:query_string]
    event[:request][:query_string] = parameter_filter.filter_param('url', query_string) if query_string

    referer = event.dig(:request, :headers, 'Referer')
    event[:request][:headers]['Referer'] = parameter_filter.filter_param('url', referer) if referer

    # Despite the name, "exception" is actually a collection of exceptions. Looks like sentry-ruby extracts nested
    # traces into their own exception. See: https://github.com/getsentry/sentry-ruby/blob/8bbfda8492e0ed77ac6ad99fab8e075cc8b1c3ac/sentry-ruby/lib/sentry/interfaces/exception.rb
    if event[:exception]
      event[:exception][:values].each do |e|
        e[:value] = parameter_filter.filter_param('url', e[:value])
      end
    end

    event[:breadcrumbs] = FilterLogging.filter_sentry_breadcrumbs(event[:breadcrumbs])

  rescue => e
    Rails.logger.error(e)
    Honeycomb.add_field('error', e.class.name)
    Honeycomb.add_field('error_detail', e.message)
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
