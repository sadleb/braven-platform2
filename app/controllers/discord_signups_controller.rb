# frozen_string_literal: true
require 'discordrb'
require 'discordrb/webhooks'

require 'salesforce_api'
require 'lti_advantage_api'
require 'lti_score'
require 'discord_bot'
require 'discordrb_proxy'

#TODO:implement everything --> this is demo
class DiscordSignupsController < ApplicationController
  include DryCrud::Controllers::Nestable
  nested_resource_of Course
  include LtiHelper

  # Adds the #publish, #publish_latest, #unpublish actions
  include Publishable

  before_action :set_lti_launch, only: [:launch]

  layout 'lti_canvas'

  class DiscordServerIdError  < StandardError; end
  # Note: this is the actual name of the assignment. The convention
  # for assignment naming is things like: CLASS: Learning Lab2,
  # MODULE: Lead Authentically, TODO: Complete Forms
  DISCORD_ASSIGNMENT_NAME = 'TODO: Complete Discord Signup'
  DISCORD_POINTS_POSSIBLE = 10.0

  DISCORD_API_TOKEN_URL = 'https://discord.com/api/v8/oauth2/token'

  def launch
    # Pass the current course into authorize so we can check enrollment.
    course = Course.find_by_canvas_course_id!(@lti_launch.course_id)
    authorize course, policy_class: DiscordSignupPolicy

    program_id = course.salesforce_program_id

    participant = HerokuConnect::Participant.with_discord_info.find_participant(
      current_user.salesforce_id, program_id
    )
    participant.add_to_honeycomb_span()

    # Show Staff/Faculty a different page, so they can't use this.
    # Checks if participant has a TA record type, but they aren't an actual TA (meaning they are staff or faculty)
    if participant.role_category == SalesforceConstants::RoleCategory::TEACHING_ASSISTANT && !participant.is_teaching_assistant?
      return render :no_discord
    end

    if needs_new_discord_state?
      @discord_state = SecureRandom.hex + ",#{@lti_launch.id}"
      Honeycomb.add_field('user.discord_state', @discord_state)

      # Save a CSRF token so we can verify in #oauth
      current_user.update!(discord_state: @discord_state)
    else
      @discord_state = current_user.discord_state
    end

    # If a user's discord_token expired, reset it to nil
    if current_user.discord_expires_at && current_user.discord_expires_at < Time.now.utc
      current_user.update!(discord_token: nil)
    end

    if current_user.discord_token
      begin
        Honeycomb.start_span(name: 'discord_signups_controller.get_discord_user') do
          response = Discordrb::API::User.profile("Bearer #{current_user.discord_token}")
          @discord_user = JSON.parse(response.body)
          Honeycomb.add_field('discord_user', @discord_user)
        end
      rescue Discordrb::Errors::UnknownError => discorderror
        Sentry.capture_exception(discorderror)

        current_user.update!(discord_token: nil)
        Honeycomb.add_alert('discord_token.reset', 'Probably safe to ignore unless this person opens a ticket.')

        redirect_to launch_discord_signups_url(lti_launch_id: @lti_launch.id), alert: 'Something went wrong, please try authorizing again.' and return
      end

      if @discord_user['email'] && @discord_user['verified']
        @discord_server_id = participant.discord_server_id
        Honeycomb.add_field('salesforce.participant.discord_server_id', @discord_server_id)
        raise DiscordServerIdError, "No Discord Server Id found for Participant.Id = #{participant.id}" if @discord_server_id.nil?

        # TODO: Decide how we want to add Discord server records to the db
        # See: https://app.asana.com/0/0/1201263861485591/f
        discord_server = DiscordServer.find_by(discord_server_id: @discord_server_id)
        raise DiscordServerIdError, "No Discord Server found in the database with the discord_server_id = #{@discord_server_id}" if discord_server.nil?

        # If the user is not already in their Discord Server, add them
        unless user_in_server?(participant)
          response = Discordrb::API::Server.add_member(
            "Bot #{Rails.application.secrets.discord_bot_token}",
            @discord_server_id,
            @discord_user['id'],
            current_user.discord_token
          )
          Honeycomb.add_field('discord_web_hook.add_member', response)

          client = Discordrb::Webhooks::Client.new(id: discord_server.webhook_id, token: discord_server.webhook_token)

          client.execute do |builder|
            builder.content = "!configure_member #{@discord_user['id']} #{participant.contact_id}"
          end

          # Only users enrolled as students can create a submission
          # The LTIAdvantageAPI call to Canvas fails for all other enrollments.
          if current_user.is_enrolled_as_student?(course)
            lti_score = LtiScore.new_full_credit_submission(
              current_user.canvas_user_id,
              completed_discord_signups_url(protocol: 'https'),
            )
            lti_advantage_api_client.create_score(lti_score)
          end
        end
      end
    end
  end

  def oauth
    authorize :discord_signup

    begin
      # Verify the CSRF token
      state, lti_launch_id = params[:state].split(",")
      raise SecurityError if current_user.discord_state != params[:state]

      # User authorized access
      # See: https://docs.microsoft.com/en-us/linkedin/shared/authentication/authorization-code-flow#your-application-is-approved
      response = Discordrb::API.request(
        :oauth2_token,
        nil,
        :post,
        DISCORD_API_TOKEN_URL,
        {
          client_id: Rails.application.secrets.discord_client_id,
          client_secret: Rails.application.secrets.discord_client_secret,
          grant_type: 'authorization_code',
          code: params[:code],
          redirect_uri: Rails.application.secrets.discord_redirect_uri
        },
        content_type: 'application/x-www-form-urlencoded'
      )

      discord_response = JSON.parse(response.body)
      discord_token_expiration = Time.now.utc + discord_response['expires_in']
      Honeycomb.add_field('user.discord_expires_at', discord_token_expiration)
      current_user.update!(
        discord_token: discord_response['access_token'],
        discord_expires_at: discord_token_expiration,
      )
    rescue Discordrb::Errors::UnknownError => discorderror
      if params[:error]
        Honeycomb.add_alert('discord_authorization_cancelled', 'The user canceled authorization.')
        Sentry.capture_exception(discorderror)
        redirect_to launch_discord_signups_url(lti_launch_id: lti_launch_id), alert: 'You clicked cancel instead of authorize. Try again and click Authorize to be added to the Braven Discord server.' and return
      else
        raise
      end
    ensure
      current_user.discord_state = ''
      current_user.save!
    end

    redirect_to launch_discord_signups_url(lti_launch_id: lti_launch_id)
  end

  # Shows a "Discord Signup Complete" page. Note that since there is no
  # local discord_signup model, we use completed instead of show b/c it's a static endpoint with
  # no id.
  # GET /discord_signups/completed
  def completed
    authorize :discord_signup
    render layout: 'lti_canvas'
  end

  def reset_assignment
    authorize :discord_signup

    current_user.update!(discord_token: nil)
    Honeycomb.add_field('discord_signups.reset_token', true)

    redirect_to launch_discord_signups_url(lti_launch_id: params[:lti_launch_id]), notice: 'Assignment successfully reset, please follow the steps to join the Braven Discord server with a new account.'
  end

private
  # Used by #publish and #publish_latest to set the Canvas assignment's name
  def assignment_name
    DISCORD_ASSIGNMENT_NAME
  end

  def points_possible
    DISCORD_POINTS_POSSIBLE
  end

  # Used by #publish to set the URL the Canvas assigment redirects to
  def lti_launch_url
    launch_discord_signups_url(protocol: 'https')
  end

  def can_publish_latest?
    false
  end

  def user_in_server?(participant)
    return false unless participant.discord_user_id.present?

    user_servers_response = Discordrb::API::User.servers("Bearer #{current_user.discord_token}")
    current_user_discord_servers = JSON.parse(user_servers_response.body)

    current_user_discord_servers.find { |server| server['id'] == participant.discord_server_id }.present?
  end

  def lti_advantage_api_client
    @lti_advantage_api_client ||= LtiAdvantageAPI.new(@lti_launch)
  end

  # Returns true if the LtiLaunch ID stored in the discord_state has already been
  # deleted, or if there is no discord state at all.
  def needs_new_discord_state?
    return true if current_user.discord_state.blank?
    LtiLaunch.from_id(current_user, current_user.discord_state&.split(',')&.last&.to_i).nil?
  end
end
