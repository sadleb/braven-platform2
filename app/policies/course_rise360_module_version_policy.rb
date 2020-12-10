class CourseRise360ModuleVersionPolicy < ApplicationPolicy
  def publish?
    edit?
  end

  def unpublish?
    edit?
  end
end
