class UsersRolePolicy < ApplicationPolicy
  attr_reader :user, :role

  def initialize(user, role)
    raise Pundit::NotAuthorizedError, "must be logged in" unless user
    @user = user
    @role = role
  end

  def destroy?
    is_admin = super 

    # Admin UsersRoles controller shouldn't be able to delete enrollments on live courses
    # Salesforce should control that so that everything is in sync and consistent (and we
    # dont make mistakes).
    is_admin and role.resource.course.is_launched == false
  end
end
