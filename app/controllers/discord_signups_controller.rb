require "discordrb"
#TODO:implement everything --> this is demo
class DiscordSignupsController < ApplicationController
  layout 'lti_canvas'

  def launch
    authorize :discord_signups

    if !current_user.discord_token
      response = Discordrb::API::User.profile("Bearer #{current_user.discord_token}")
      @discord_user = JSON.parse(response.body)

      if @discord_user["email"] && @discord_user["verified"]
        Discordrb::API::Server.add_member("Bot #{Rails.application.secrets.bot_token}", "722098701878689933", @discord_user["id"], current_user.discord_token)
      end
    end
  end

  def oauth
    authorize :discord_signups

    response = Discordrb::API.request(:oauth2_token, nil, :post, 'https://discord.com/api/v8/oauth2/token', {client_id: Rails.application.secrets.discord_client_id, client_secret: Rails.application.secrets.discord_client_secret, grant_type: 'authorization_code', code: params[:code], redirect_uri: Rails.application.secrets.discord_redirect_uri}, content_type: 'application/x-www-form-urlencoded')

    current_user.update!(discord_token: JSON.parse(response.body)["access_token"])

    redirect_to launch_discord_signups_url
  end
end
