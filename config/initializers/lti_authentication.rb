# frozen_string_literal: true
Rails.configuration.to_prepare do

require 'lti_launch'

# This module is responsible for handling authentication for LtiLaunches that don't have access
# to normal Devise session based authentication. For example, in Chrome incognito mode third
# party cookies are blocked by default so when we run in an iFrame on Canvas our cookies aren't
# set by the browser causing authentication to fallback to this.
module LtiAuthentication

  class WardenStrategy < Warden::Strategies::Base

    # True if this strategy should be run for this request
    def valid?
      @lti_state = fetch_state
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
          message = "LtiAuthentication::WardenStrategy couldn't find LtiLaunch with state = '#{@lti_state}'"
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
      else
        Rails.logger.warn(message)
        handle_failure(status)
      end
    end

    # There are 5 possible locations where the lti state may be stored in a request:
    # params[:state] is there for routes hit using LtiLaunchController
    # params[:auth] is there when Rise360 packages load index.html. We piggyback off the "auth" query param that Rise
    #               packages can be configured with and store it there when launching them.
    # request.headers[:authorization] is there for Ajax requests from both Rise360 and Projects. For Rise360 this
    #                                 is the result of configuring Tincan.js with the "auth" option in the launch.
    # request.referrer contains a state token when an iframe is loaded *inside* Rise360 content.
    # request.referrer contains a state token when an iframe is loaded *inside* CustomContent (Projects).
    def fetch_state
      lti_state = params[:state]
      unless lti_state
        lti_state = params[:auth][/#{LtiConstants::AUTH_HEADER_PREFIX} (.*)$/, 1] if params[:auth]
      end
      unless lti_state
        lti_state = request.headers[:authorization][/#{LtiConstants::AUTH_HEADER_PREFIX} (.*)$/, 1] if request.headers[:authorization]
      end
      unless lti_state
        lti_state = LtiHelper.get_lti_state_from_referrer(request)
      end
      lti_state
    end

    def handle_failure(response)
      custom!(response)
    end

  end
end

end # END to_prepare
