# frozen_string_literal: true

# This concern is included in ApplicationController, so you probably
# don't want to use it anywhere else.

module Rescuable
  extend ActiveSupport::Concern

  included do
    unless Rails.application.config.consider_all_requests_local
      # In order from least to most specific.
      rescue_from StandardError, :with => :handle_error_generic
      rescue_from Pundit::NotAuthorizedError, :with => :handle_error_forbidden
    end
  end

private

  def handle_error_forbidden(exception)
    capture_error(exception)

    @exception = exception
    render 'errors/not_authorized', layout: 'lti_canvas', status: 403
  end

  def handle_error_generic(exception)
    capture_error(exception)

    @request = request
    render 'errors/internal_server_error', layout: 'lti_canvas', status: 500
  end

  def capture_error(exception)
    Rails.logger.error exception.backtrace.join("\n\t")
      .sub("\n\t", ": #{exception}#{exception.class ? " (#{exception.class})" : ''}\n\t")
    Sentry.capture_exception(exception)
    Honeycomb.client.send(:add_exception_data, Honeycomb.current_span, exception) if Honeycomb.current_span
  end

end