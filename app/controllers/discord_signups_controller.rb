# frozen_string_literal: true
require 'discordrb'
require 'discordrb/webhooks'

require 'salesforce_api'
require 'discord_bot'

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
  # MODULE: Lead Authentically, TODO: Complete Waivers
  DISCORD_ASSIGNMENT_NAME = 'TODO: Complete Discord Signup'
  DISCORD_POINTS_POSSIBLE = 10.0

  def launch
    authorize :discord_signup

    user_discord_state = current_user.discord_state
    if user_discord_state.blank?
      @discord_state = SecureRandom.hex + ",#{@lti_launch.id}"
      Honeycomb.add_field('user.discord_state', @discord_state)

      # Save a CSRF token so we can verify in #oauth
      current_user.update!(discord_state: @discord_state)
    else
      @discord_state = user_discord_state
    end

    # If a user's discord_token expired, reset it to nil
    if current_user.discord_expires_at && current_user.discord_expires_at < Time.now.utc
      current_user.update!(discord_token: nil)
    end

    if current_user.discord_token
      response = Discordrb::API::User.profile("Bearer #{current_user.discord_token}")
      @discord_user = JSON.parse(response.body)

      if @discord_user['email'] && @discord_user['verified']
        course = Course.find_by_canvas_course_id!(@lti_launch.course_id)
        program_id = course.salesforce_program_id

        participant = SalesforceAPI.client.find_participant(
          contact_id: current_user.salesforce_id, program_id: program_id
        )

        @discord_server_id = participant.discord_server_id
        raise DiscordServerIdError, "No Discord Server Id found for Participant.Id = #{participant.id}" if @discord_server_id.nil?

        contact = SalesforceAPI.client.get_contact_info(participant.contact_id)
        nickname = DiscordBot.compute_nickname(contact)

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
            current_user.discord_token,
            nickname
          )
          Honeycomb.add_field('discord_web_hook.add_member', response)

          client = Discordrb::Webhooks::Client.new(id: discord_server.webhook_id , token: discord_server.webhook_token)

          client.execute do |builder|
            builder.content = "!configure_member #{@discord_user['id']} #{contact['Id']}"
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
        'https://discord.com/api/v8/oauth2/token',
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
      current_user.update!(
        discord_token: discord_response['access_token'],
        discord_expires_at: discord_token_expiration,
      )
    rescue Discordrb::Errors::UnknownError => discorderror
      if params[:error]
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
end
