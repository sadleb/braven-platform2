class DiscordSignupPolicy < ApplicationPolicy
  def launch?
    !!user
  end

  def oauth?
    !!user
  end

  def publish?
    edit?
  end
  
  def unpublish?
    edit?
  end
end
