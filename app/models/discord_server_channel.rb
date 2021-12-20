# frozen_string_literal: true

class DiscordServerChannel < ApplicationRecord
  # Note discord_server_id refers to local `DiscordServer.id`, not
  # the external Discord `server.id`.
  validates :name, :discord_server_id, :discord_channel_id, :position, presence: true
  validates :discord_channel_id, uniqueness: true
  validates :name, uniqueness: { scope: [:discord_server_id] }
  validates :discord_channel_id, numericality: true

  belongs_to :discord_server
  alias_attribute :server, :discord_server
end
