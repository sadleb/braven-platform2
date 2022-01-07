# frozen_string_literal: true

require 'discordrb'
require 'discord_bot'

class SyncDiscordServers

  def initialize
  end

  def run
    Honeycomb.start_span(name: 'sync_discord_servers.run') do
      # Loop over servers in the local db, and update their channel/role info
      # from the Discord API.
      DiscordServer.all.each do |server|
        sync_server(server)
      end
    end
  end

  def sync_server(server)
    Rails.logger.info("Starting sync for discord_server_id=#{server.discord_server_id}")
    Honeycomb.start_span(name: 'sync_discord_servers.sync_server') do
      Honeycomb.add_field('discord_server.id', server.id.to_s)
      Honeycomb.add_field('discord.server.name', server.name)
      Honeycomb.add_field('discord.server.id', server.discord_server_id)

      sync_server_channels(server)
      sync_server_roles(server)
    end
  end

  def sync_server_channels(server)
    response = Discordrb::API::Server.channels("Bot #{Rails.application.secrets.discord_bot_token}", server.discord_server_id)
    channels = JSON.parse(response.body)

    # Remove deleted channels.
    deleted_channels = server.channels.map { |c| c.discord_channel_id } - channels.map { |c| c['id'].to_s }
    Rails.logger.info("Deleting channels: #{deleted_channels}")
    Honeycomb.add_field('sync_discord_servers.deleted_channels', deleted_channels)
    DiscordServerChannel.where(discord_channel_id: deleted_channels).destroy_all

    # Add/update channels.
    channels.each do |channel_data|
      next if channel_data['name'].start_with? COHORT_CHANNEL_PREFIX
      next unless channel_data['type'] == TEXT_CHANNEL
      Rails.logger.info("Syncing channel '#{channel_data['name']}'")

      channel = DiscordServerChannel.find_by(discord_channel_id: channel_data['id'])
      
      if channel
        channel.update!(
          position: channel_data['position'],
          name: channel_data['name'],
        )
      else
        DiscordServerChannel.create!(
          # Note since channel.discord_server_id field name is ambiguous, it
          # will always refer to the local DiscordServer id.
          discord_server_id: server.id,
          discord_channel_id: channel_data['id'],
          position: channel_data['position'],
          name: channel_data['name'],
        )
      end
    end
  end

  def sync_server_roles(server)
    response = Discordrb::API::Server.roles("Bot #{Rails.application.secrets.discord_bot_token}", server.discord_server_id)
    roles = JSON.parse(response.body)

    # Remove deleted roles.
    deleted_roles = server.roles.map { |c| c.discord_role_id } - roles.map { |c| c['id'].to_s }
    Rails.logger.info("Deleting roles: #{deleted_roles}")
    Honeycomb.add_field('sync_discord_servers.deleted_roles', deleted_roles)
    DiscordServerRole.where(discord_role_id: deleted_roles).destroy_all

    # Add/update roles.
    roles.each do |role_data|
      next if role_data['name'].start_with? COHORT_ROLE_PREFIX
      next if role_data['name'] == EVERYONE_ROLE
      Rails.logger.info("Syncing role '#{role_data['name']}'")

      role = DiscordServerRole.find_by(discord_role_id: role_data['id'])
      
      if role
        role.update!(
          name: role_data['name'],
        )
      else
        DiscordServerRole.create!(
          # Note since role.discord_server_id field name is ambiguous, it
          # will always refer to the local DiscordServer id.
          discord_server_id: server.id,
          discord_role_id: role_data['id'],
          name: role_data['name'],
        )
      end
    end
  end
end
