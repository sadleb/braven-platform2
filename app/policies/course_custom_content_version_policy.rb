class CourseCustomContentVersionPolicy < CustomContentVersionPolicy
  def publish?
    edit?
  end

  def publish_latest?
    edit?
  end

  def unpublish?
    edit?
  end
end
