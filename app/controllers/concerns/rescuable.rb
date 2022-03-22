# frozen_string_literal: true

# This concern is included in ApplicationController, so you probably
# don't want to use it anywhere else.

module Rescuable
  extend ActiveSupport::Concern

  included do
    unless Rails.application.config.consider_all_requests_local
      # In order from least to most specific.
      rescue_from StandardError, :with => :handle_error_generic
      rescue_from GenerateZoomLinks::GenerateZoomLinksError, :with => :handle_generate_zoom_links_error
      rescue_from Pundit::NotAuthorizedError, :with => :handle_error_forbidden
      rescue_from ActionController::InvalidAuthenticityToken, with: :handle_invalid_authenticity_token
      rescue_from SecurityError, :with => :handle_security_error
      rescue_from LtiConstants::LtiAuthenticationError, :with => :handle_lti_auth_error
    end
  end

private

  def handle_error_forbidden(exception)
    capture_error(exception)

    @exception = exception
    render 'errors/not_authorized', :formats => [:html], layout: 'lti_canvas', status: 403
  end

  def handle_error_generic(exception)
    capture_error(exception)

    @request = request
    render 'errors/internal_server_error', layout: 'lti_canvas', status: 500
  end

  def handle_invalid_authenticity_token(exception)
    capture_error(exception)

    # Get only the path portion of the referrer, so this page doesn't introduce
    # an open redirect vulnerability.
    @referrer_path = Addressable::URI.parse(request.referrer)&.request_uri
    render 'errors/invalid_authenticity_token', layout: 'lti_canvas', status: 500
  end

  def handle_security_error(exception)
    capture_error(exception)

    @request = request
    render 'errors/security_error', layout: 'lti_canvas', status: 500
  end

  def handle_generate_zoom_links_error(exception)
    capture_error(exception)

    @exception = exception
    render 'errors/generate_zoom_links_error', layout: 'lti_canvas', status: 500
  end

  def handle_lti_auth_error(exception)
    capture_error(exception)

    @request = request
    @exception = exception
    render 'errors/lti_auth_error', layout: 'lti_canvas', status: 500
  end

  def capture_error(exception)
    Rails.logger.error exception.backtrace.join("\n\t")
      .sub("\n\t", ": #{exception}#{exception.class ? " (#{exception.class})" : ''}\n\t")
    Sentry.capture_exception(exception)
    Honeycomb.client.send(:add_exception_data, Honeycomb.current_span, exception) if Honeycomb.current_span
  end

end
