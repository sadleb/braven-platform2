class CourseContentPolicy < ApplicationPolicy
  def publish?
    user&.admin?
  end
end
