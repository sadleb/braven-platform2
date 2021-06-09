class CourseRise360ModuleVersionPolicy < ApplicationPolicy
  def publish?
    edit?
  end

  def publish_latest?
    edit?
  end

  def before_publish_latest?
    edit?
  end

  def unpublish?
    edit?
  end

  def before_unpublish?
    edit?
  end
end
