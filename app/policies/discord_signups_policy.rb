class DiscordSignupsPolicy < ApplicationPolicy
  def launch?
    !!user
  end

  def oauth?
    !!user
  end
end
