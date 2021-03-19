# frozen_string_literal: true
require 'rack/proxy'
require 'uri'
require_relative 'rise360_util'

# Implements a reverse proxy to our published LessonContent on AWS S3.
# Needed to avoid security concerns with cross origin / AJAX / XHR browser issues.
# More context: https://app.asana.com/0/1174274412967132/1186566037117865
#
# Hitting a path like:
#
#   https://platformweb/rise360_proxy/the/path/on/aws/s3
# 
# will cause the request/response to be proxied to the configured AWS S3 bucket at
#
#   https://bucket.s3.amazonaws.com/the/path/on/aws/s3
#
class LtiRise360Proxy < Rack::Proxy

  PROXIED_PATH='/rise360_proxy'
  PROXY_REGEX=/^#{Regexp.escape(PROXIED_PATH)}(\/.*)$/

  # E.g. https://platformweb/lesson_contents_proxy
  def self.proxy_url
    # This is hard-coded to HTTPS b/c none of this stuff works over HTTP and in dev thats the default
    # if we use a helper URL like: Rails.application.routes.url_helpers.root_url
    @proxy_url ||= "https://#{Rails.application.secrets.application_host}#{PROXIED_PATH}"
  end

  def perform_request(env)
    request = Rack::Request.new(env)

    if request.path =~ PROXY_REGEX
      return [401, {}, ['Unauthorized']] unless authenticate(request)

      path = $1 # from regex match above
      uri = URI(Rise360Util.presigned_url(path))

      env['HTTP_HOST'] = uri.host           # e.g. some-bucket.s3.amazonaws.com
      env['PATH_INFO'] = uri.path           # The path matched in the regex above
      env['QUERY_STRING'] = uri.query       # The AWS query params signing it

      super(env)
    else
      @app.call(env)
    end
  end

private

  # Authentication is handled by Warden in Rails/Rack:
  # https://github.com/wardencommunity/warden/wiki
  # This is a proxy / middleware endpoint that doesn't go through
  # the normal Rails controller routing, so we have to handle this
  # ourselves
  def authenticate(request)
    # Exclude fonts from authentication. They are linked into CSS stylesheets and the
    # state param is not in the referer when loaded. E.g. let icomoon.ttf and icomoon.woff load
    return true if request.env['PATH_INFO'] =~ /\/lib\/fonts/

    warden = request.env['warden']
    return false unless warden
    return true if warden.authenticated? # short circuit if already authenticated using session

    # Authenticate but don't fail out b/c it would try redirecting to login.
    # Just return if it fails so we respond with a 401
    warden.authenticate 
    return true if warden.user
    false
  end
end
