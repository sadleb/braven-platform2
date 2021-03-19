# frozen_string_literal: true

require 'json'
require 'rest-client'
require 'uri'

require 'linked_in_api'

class LinkedInAuthorizationController < ApplicationController
  include LtiHelper

  before_action :set_lti_launch_from_referrer, only: [:login]
  # We only need set_lti_launch on #launch, because once the launch page loads
  # it sets a same-domain cookie, and we don't have to worry about passing
  # state around any more.
  before_action :set_lti_launch, only: [:launch]

  layout 'lti_canvas'

  # iframe-able endpoint that renders a static LinkedIn button
  def login
    authorize :LinkedInAuthorization
  end

  # Genereates and renders the LinkedIn authorization URL in the current
  # window after doing some server-side set-up
  def launch
    authorize :LinkedInAuthorization

    state = SecureRandom.hex
    redirect_url = linked_in_auth_redirect_url

    Honeycomb.add_field('user.linked_in_state', state)

    # Save a CSRF token so we can verify in #redirect
    current_user.linked_in_state = state
    current_user.save!

    @authorization_url = LinkedInAPI.authorize_url(
      redirect_url,
      state,
    )
  end

  # Redirect endpoint for LinkedIn authorization flow
  def oauth_redirect
    authorize :LinkedInAuthorization

    Honeycomb.add_field('user.linked_in_state', current_user.linked_in_state)

    begin
      # Verify the CSRF token
      raise SecurityError if current_user.linked_in_state != params[:state]

      # User didn't authorize LinkedIn access
      # See: https://docs.microsoft.com/en-us/linkedin/shared/authentication/authorization-code-flow#application-is-rejected
      return unless params[:code]

      # User authorized access
      # See: https://docs.microsoft.com/en-us/linkedin/shared/authentication/authorization-code-flow#your-application-is-approved
      access_token = LinkedInAPI.exchange_code_for_token(
        linked_in_auth_redirect_url,
        params[:code],
      )
      current_user.linked_in_access_token = access_token
    ensure
      # Consume the CSRF token
      current_user.linked_in_state = ''
      current_user.save!
    end
  end
end
