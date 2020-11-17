# Only available to logged-in users, so return false if user is nil.
class WaiversPolicy < ApplicationPolicy
  def launch?
    !!user
  end

  def publish?
    edit?
  end

  def unpublish?
    edit?
  end
end
