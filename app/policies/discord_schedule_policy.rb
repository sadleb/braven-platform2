class DiscordSchedulePolicy < ApplicationPolicy

  def index?
    user.can_schedule_discord?
  end

  def create?
    index?
  end

  def new?
    index?
  end

  def destroy?
    index?
  end

end
