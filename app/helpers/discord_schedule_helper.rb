module DiscordScheduleHelper
  # Discord raw role-mention syntax:
  ROLE_MENTION_REGEX = /<@&(\d+)>/

  def render_discord_message(message)
    # For now, this is just the inverse of
    # ScheduleDiscordMessage.convert_role_mentions.
    message.scan(ROLE_MENTION_REGEX).flatten.each do |discord_role_id|
      # This is a raw role mention.
      role = DiscordServerRole.find_by(discord_role_id: discord_role_id)
      # Skip invalid role IDs, instead of crashing.
      next unless role

      # Convert raw role mentions to the human-readable format.
      message = message.sub("<@&#{discord_role_id}>", "@#{role.name}")
    end

    message
  end
end
