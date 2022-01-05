# frozen_string_literal: true

require 'discord_bot'

class ScheduleDiscordMessage

  def initialize(discord_server_id, discord_server_channel_id, message, datetime, timezone)
    @discord_server_id = discord_server_id
    @discord_server_channel_id = discord_server_channel_id
    @message = message
    @datetime = datetime
    @timezone = timezone
  end

  def run
    Honeycomb.start_span(name: 'schedule_discord_message.run') do
      run_at = Time.use_zone(@timezone) { Time.zone.parse(@datetime) }

      Honeycomb.add_field('schedule_discord_message.run_at', run_at.to_s)
      Honeycomb.add_field('discord_server.id', @discord_server_id.to_s)
      Honeycomb.add_field('discord_server_channel.id', @discord_server_channel_id.to_s)

      # Convert from local DiscordServer.id to 3rd-party Discord server ID.
      server_id = DiscordServer.find(@discord_server_id).discord_server_id.to_i

      Honeycomb.add_field('discord.server.id', server_id.to_s)

      # Convert from Channel ID to channel name.
      if @discord_server_channel_id == COHORT_CHANNEL_PREFIX
        # This is a shortcut to send a message to all cohort channels.
        channel_name = COHORT_CHANNEL_PREFIX
      else
        channel_name = DiscordServerChannel.find(@discord_server_channel_id).name
      end

      Honeycomb.add_field('discord.channel.name', channel_name)

      message_content = @message

      # Schedule the job.
      SendDiscordMessageJob.set(wait_until: run_at).perform_later(server_id, channel_name, message_content)
    end
  end
end
