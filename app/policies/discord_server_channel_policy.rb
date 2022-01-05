class DiscordServerChannelPolicy < ApplicationPolicy

  def index?
    user.can_schedule_discord?
  end

end
