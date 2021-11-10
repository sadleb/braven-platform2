# frozen_string_literal: true

# Manage DiscordServer records in the db.
class DiscordServersController < ApplicationController
  layout 'admin'

  include DryCrud

  WEBHOOK_URL_REGEX = /^#{Regexp.escape(DiscordServer::WEBHOOK_URL_BASE)}\/(?<webhook_id>\d+)\/(?<webhook_token>[a-zA-Z0-9_-]+)$/

  def index
    authorize DiscordServer
  end

  def new
    authorize DiscordServer
  end

  def create
    authorize DiscordServer
    
    webhook_data = WEBHOOK_URL_REGEX.match(discord_server_params[:webhook_url])

    DiscordServer.create!(
      name: discord_server_params[:name],
      discord_server_id: discord_server_params[:discord_server_id],
      webhook_id: webhook_data.try(:[], :webhook_id),
      webhook_token: webhook_data.try(:[], :webhook_token),
    )

    redirect_to discord_servers_path, notice: 'Server added!'
  end

  def destroy
    authorize DiscordServer

    @discord_server.destroy!

    redirect_to discord_servers_path, notice: 'Server removed!'
  end

private

  def discord_server_params
    params.require(:discord_server).permit(:name, :discord_server_id, :webhook_url)
  end
end
