class CourseContentHistoryPolicy < ApplicationPolicy
  def show?
    !!user
  end
end
