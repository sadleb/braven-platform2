class RateThisModuleSubmissionPolicy < ApplicationPolicy
  def initialize(user, record)
    raise Pundit::NotAuthorizedError, "must be logged in" unless user
    raise Pundit::NotAuthorizedError, "no submission specified" unless record
    @user = user
    @record = record
  end

  def launch?
    # Admins get special permission to read, but not write, all submissions.
    # LCs/TAs don't need to see RateThisModule responses.
    return true if user.admin?

    update?
  end

  def edit?
    # Admins get special permission to read, but not write, all submissions.
    # LCs/TAs don't need to see RateThisModule responses.
    return true if user.admin?

    update?
  end

  def update?
    # No one can update submissions that aren't their own.
    # Only admins can read submissions that aren't their own.
    return false unless user == record.user

    # Users can rate modules attached to a course they are enrolled in.
    user.can_access?(record)
  end
end
