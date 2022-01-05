json.array! @discord_server_channels.sort_by(&:position), partial: "discord_server_channels/discord_server_channel", as: :discord_server_channel
