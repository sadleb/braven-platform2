class AcceleratorSurveyPolicy < ApplicationPolicy
  def publish?
    edit?
  end

  def unpublish?
    edit?
  end
end
