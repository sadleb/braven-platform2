# frozen_string_literal: true
Rails.configuration.to_prepare do

require 'lti_launch'

# This module is responsible for handling authentication for LtiLaunches that don't have access
# to normal Devise session based authentication. For example, in Chrome incognito mode third
# party cookies are blocked by default so when we run in an iFrame on Canvas our cookies aren't
# set by the browser causing authentication to fallback to this.
module LtiAuthentication

  class WardenStrategy < Warden::Strategies::Base
    include Rails.application.routes.url_helpers

    # True if this strategy should be run for this request
    def valid?

      # Don't run this if We're still doing the Lti Authentication handshake in the lti_launch_controller.
      # The state doesn't become valid until the 'POST /lti/launch' finishes and redirects.
      return false if request.path == lti_launch_path

      @lti_state = fetch_state
      Honeycomb.add_field('app.lti_authentication.valid?', @lti_state.present?)
      @lti_state.present?
    end

    def authenticate!
      Honeycomb.start_span(name: 'LtiAuthentication.authenticate!') do |span|
        user = nil
        url = nil
        status = nil
        message = nil
        canvas_id = nil

        # TODO: cache this for an hour. Or a day? It's hit alot.
        # https://app.asana.com/0/1174274412967132/1188248367583275
        unless ll = LtiLaunch.is_valid?(@lti_state)
          status = :forbidden
          message = "LtiAuthentication::WardenStrategy couldn't find LtiLaunch using state value"
          return finish_authenticate(span, status, message)
        end

        url = ll.target_link_uri
        canvas_id = ll.request_message.canvas_user_id
        unless user = ll.user
          status = :forbidden
          message = "LtiAuthentication::WardenStrategy couldn't find user with canvas_id = #{canvas_id}"
          return finish_authenticate(span, status, message, url, canvas_id)
        end

        status = :ok
        message = "LtiAuthentication::WardenStrategy done authenticating user_id = #{user.id}"
        unless ll.sessionless
          ll.sessionless = true
          ll.save!
        end
        return finish_authenticate(span, status, message, url, canvas_id, user)
      end
    end

private

    def finish_authenticate(span, status, message, url = nil, canvas_id = nil, user = nil)
      span.add_field('app.lti_authentication.status', status&.to_s)
      span.add_field('app.lti_authentication.message', message)
      span.add_field('app.lti_authentication.url', url)
      user&.add_to_honeycomb_trace

      if status == :ok
        Rails.logger.debug(message)
        success!(user)
      elsif status == :forbidden
        Rails.logger.warn(message)
        custom!([403,{'Content-Type' => 'text/plain'},["403 Forbidden"]])
      else # this is a code bug if we get here
        Rails.logger.error(message)
        fail!('Unknown server error')
      end
    end

    # There are 2 possible locations where the lti state may be stored in a request:
    #
    # * params[:state] is there for routes hit using LtiLaunchController
    # * request.headers[:authorization] is there for Ajax requests from both Rise360 and Projects.
    #   For Rise360 this is the result of configuring Tincan.js with the "auth" option in the launch.
    #
    # Important note: Be sure to never use any lti_launch_id param for authentication! That param
    # is only to identify the launch in non-auth-related contexts, such as pulling the associated
    # Canvas course/assignment IDs.
    def fetch_state
      lti_state = params[:state]
      Honeycomb.add_field('lti_authentication.fetch_state_from', 'params[:state]') if lti_state

      unless lti_state
        lti_state = request.headers[:authorization][/#{LtiConstants::AUTH_HEADER_PREFIX} (.*)$/, 1] if request.headers[:authorization]
        Honeycomb.add_field('lti_authentication.fetch_state_from', 'headers[:authorization]') if lti_state
      end

      Honeycomb.add_field('lti_authentication.fetch_state_from', 'none') unless lti_state

      lti_state
    end

  end
end

end # END to_prepare
