require 'filter_logging'

# https://docs.sentry.io/platforms/ruby/guides/rails/configuration/options/
Sentry.init do |config|

  config.dsn = ENV['SENTRY_DSN']

  config.breadcrumbs_logger = [:active_support_logger]

  # Activates performance monitoring, sending the below percent of events when sampling.
  # Increase this to get more precise data at the expense of more bandwidth used.
  # config.traces_sample_rate = 0.3

  # Defaults to false which prevents Sentry from sending personally identifiable
  # information (pii), such as request body, user ip or cookies. They
  # recommend setting this to true and then manually scrubbing what you don't want
  # sent using the before_send hook below or one of the methods described here:
  # https://docs.sentry.io/platforms/javascript/data-management/sensitive-data/
  config.send_default_pii = true

  # Some exceptions are not sent to Sentry by default. Here we're explicitly overriding 
  # that to specify which exceptions should not be sent to Sentry.
  # I spent too much time thinking it was a Sentry connection issue when one of
  # these wasn't coming through. I think the only reason not to send certain exceptions
  # to is if they are generated a ton in the wild by bots/hackers trying to
  # exploit the server and they would have been found during development pretty easily?
  config.excluded_exceptions = [
    ##################
    # Taken from sentry-rails IGNORE_DEFULT array here:
    # https://github.com/getsentry/sentry-ruby/blob/master/sentry-rails/lib/sentry/rails/configuration.rb#L12
    #
    # Commenting out those that I think we want to see? We can uncomment them if
    # we start getting bombarded.
    'AbstractController::ActionNotFound',
    #'ActionController::BadRequest',
    'ActionController::InvalidAuthenticityToken',
    'ActionController::InvalidCrossOriginRequest',
    'ActionController::MethodNotAllowed',
    'ActionController::NotImplemented',
    #'ActionController::ParameterMissing',
    'ActionController::RoutingError',
    'ActionController::UnknownAction',
    #'ActionController::UnknownFormat',
    #'ActionDispatch::Http::MimeNegotiation::InvalidType',
    'ActionController::UnknownHttpMethod',
    #'ActionDispatch::Http::Parameters::ParseError',
    #'ActiveRecord::RecordNotFound'

    ################
    # Taken from sentry-ruby IGNORE_DEFAULT array here:
    # https://github.com/getsentry/sentry-ruby/blob/master/sentry-ruby/lib/sentry/configuration.rb#L151
    #'Rack::QueryParser::InvalidParameterError',
    #'Rack::QueryParser::ParameterTypeError',
    'Mongoid::Errors::DocumentNotFound',
    'Sinatra::NotFound',

    ################
    # Add any other exceptions to not send here:
  ]

  config.before_send = lambda do |event, hint|
    FilterLogging.filter_sentry_data(event, hint)
  end

  # Note: this hook wasn't working. Doing this in the above before_send instead.
  #config.before_breadcrumb = lambda do |breadcrumb, hint|
  #  FilterLogging.filter_sentry_breadcrumbs(breadcrumb, hint)
  #end

end

