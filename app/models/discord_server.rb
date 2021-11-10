# frozen_string_literal: true

class DiscordServer < ApplicationRecord
  validates :name, :discord_server_id, :webhook_id, :webhook_token, presence: true
  validates :name, :discord_server_id, :webhook_id, uniqueness: true
  validates :discord_server_id, :webhook_id, numericality: true

  WEBHOOK_URL_BASE = 'https://discord.com/api/webhooks'
  SERVER_URL_BASE = 'https://discord.com/channels'

  def webhook_url
    "#{WEBHOOK_URL_BASE}/#{webhook_id}/#{webhook_token}" if webhook_id && webhook_token
  end

  def server_url
    "#{SERVER_URL_BASE}/#{discord_server_id}" if discord_server_id
  end
end
