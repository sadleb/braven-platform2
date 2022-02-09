class CustomContentVersionPolicy < ApplicationPolicy
  def show?
    # Delegate to logic in the user model.
    return true if user&.can_access?(record)

    raise Pundit::NotAuthorizedError, message: ERROR_ENROLLMENT_GENERIC
  end
end
