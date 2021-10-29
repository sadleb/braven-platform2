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

        # Add user to their Discord Server
        Discordrb::API::Server.add_member(
          "Bot #{Rails.application.secrets.discord_bot_token}",
          @discord_server_id,
          @discord_user['id'],
          current_user.discord_token,
          nickname
        )

        client = Discordrb::Webhooks::Client.new(id: discord_server.webhook_id , token: discord_server.webhook_token)

        client.execute do |builder|
          builder.content = "!configure_member #{@discord_user['id']} #{contact['Id']}"
        end
      end
    end
  end

  def oauth
    authorize :discord_signup

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
    current_user.update!(discord_token: JSON.parse(response.body)['access_token'])
    redirect_to launch_discord_signups_url
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
end
