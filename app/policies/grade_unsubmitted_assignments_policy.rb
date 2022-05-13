class GradeUnsubmittedAssignmentsPolicy < ApplicationPolicy
  def grade?
    update?
  end
end
