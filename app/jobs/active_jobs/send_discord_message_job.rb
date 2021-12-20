# frozen_string_literal: true

class SendDiscordMessageJob < ApplicationJob
  queue_as :default

  def perform(server_id, channel_name, message_content)
    service = SendDiscordMessage.new(server_id.to_i, channel_name, message_content)
    service.run
  end

end
