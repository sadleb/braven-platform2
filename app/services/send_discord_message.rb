# frozen_string_literal: true
# Start a bot instance, send a single Discord message, and exit.

require 'discordrb'
require 'discord_bot'

class SendDiscordMessage

  def initialize(server_id, channel_name, message_content)
    @server_id = server_id.to_i
    @channel_name = channel_name
    @message_content = message_content
    @token = Rails.application.secrets.discord_bot_token
  end

  def run
    bot = Discordrb::Bot.new(token: @token, log_mode: :info)

    # Event handler: The bot is fully connected to the websocket API.
    bot.ready do |event|
      # Send the message.
      Honeycomb.start_span(name: 'send_discord_message.on_ready') do
        Honeycomb.add_field('discord.server.id', @server_id.to_s)
        Honeycomb.add_field('discord.channel.name', @channel_name)

        if @channel_name == COHORT_CHANNEL_PREFIX
          # This is a shortcut to send the message to all cohort channels.
          channels = bot.servers[@server_id]&.channels.select { |c|
            c.type == TEXT_CHANNEL &&
            c.name.start_with?(@channel_name) &&
            c.name != COHORT_TEMPLATE_CHANNEL
          }
          # Track usage of this shortcut feature, so we can delete it if it's unused.
          Honeycomb.add_field('send_discord_message.all_cohort_channels?', true)
          channels.each do |channel|
            channel.send_message(@message_content)
          end
        else
          # Normal channel message to a single channel.
          channel = bot.servers[@server_id]&.channels.find { |c| c.type == TEXT_CHANNEL && c.name == @channel_name }

          Honeycomb.add_field('discord.channel.id', channel&.id.to_s)

          # If the channel didn't exist, crash. HC/Sentry will be notified.
          # We could do extra work to alert staff, but let's not until we need it.

          channel.send_message(@message_content)
        end

        # Bye!
        bot.stop
      end
    rescue => e
      # Stop the bot if we encounter any errors, otherwise this job will hang forever.
      bot.stop
      raise
    end

    # Run the bot (synchronous, blocks forever).
    bot.run
  end
end
