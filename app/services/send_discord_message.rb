# frozen_string_literal: true
# Start a bot instance, send a single Discord message, and exit.

require 'discordrb'

class SendDiscordMessage

  def initialize(server_id, channel_name, message_content)
    @server_id = server_id.to_i
    @channel_name = channel_name
    @message_content = message_content
    @token = ENV['BOT_TOKEN']
  end

  def run
    bot = Discordrb::Bot.new(token: @token, log_mode: :info)

    # Event handler: The bot is fully connected to the websocket API.
    bot.ready do |event|
      # Send the message.
      Honeycomb.start_span(name: 'send_discord_message.on_ready') do
        Honeycomb.add_field('server.id', @server_id.to_s)
        Honeycomb.add_field('channel.name', @channel_name)

        # Channel type 0 = text channel.
        channel = bot.servers[@server_id]&.channels.find { |c| c.type == 0 && c.name == @channel_name }

        Honeycomb.add_field('channel.id', channel&.id)

        # If the channel didn't exist, crash. HC/Sentry will be notified.
        # We could do extra work to alert staff, but let's not until we need it.

        channel.send_message(@message_content)

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
