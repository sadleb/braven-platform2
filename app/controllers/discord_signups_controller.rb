# frozen_string_literal: true
require 'discordrb'
require 'discordrb/webhooks'

require 'salesforce_api'
require 'discord_bot'

#TODO:implement everything --> this is demo
class DiscordSignupsController < ApplicationController
  layout 'lti_canvas'
  class DiscordServerIdError  < StandardError; end

  def launch
    authorize :discord_signups

    if current_user.discord_token
      response = Discordrb::API::User.profile("Bearer #{current_user.discord_token}")
      @discord_user = JSON.parse(response.body)

      if @discord_user['email'] && @discord_user['verified']

        # TODO: there is a bug here where we just use the first Enrolled Participant we find.
        # We haven't made a decision on where this page will live yet and whether we'll have
        # access to an lti_launch in order to get the course and then program. Once that decision
        # is made, fix this to get the Participant for the program in this context.
        # and then we should enroll them in all Programs they are Enrolled Participants for:
        # https://app.asana.com/0/1201131148207877/1201246645700111
        participant = SalesforceAPI.client.find_participants_by_contact_id(
          contact_id: current_user.salesforce_id, filter_by_status: SalesforceAPI::ENROLLED
        ).first

        discord_server_id = participant.discord_server_id
        raise DiscordServerIdError, "No Discord Server Id found for Participant.Id = #{participant.id}" if discord_server_id.nil?

        contact = SalesforceAPI.client.get_contact_info(participant.contact_id)
        nickname = DiscordBot.compute_nickname(contact)

        # TODO: Decide how we want to add Discord server records to the db
        # See: https://app.asana.com/0/0/1201263861485591/f
        discord_server = DiscordServer.find_by(discord_server_id: discord_server_id)
        raise DiscordServerIdError, "No Discord Server found in the database with the discord_server_id = #{discord_server_id}" if discord_server.nil?

        client = Discordrb::Webhooks::Client.new(id: discord_server.webhook_id , token: discord_server.webhook_token)

        client.execute do |builder|
          builder.content = "!configure_member #{@discord_user['id']} #{contact['Id']}"
        end

        # Add user to their Discord Server
        Discordrb::API::Server.add_member(
          "Bot #{Rails.application.secrets.bot_token}",
          discord_server_id,
          @discord_user['id'],
          current_user.discord_token,
          nickname
        )
      end
    end
  end

  def oauth
    authorize :discord_signups

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
end
