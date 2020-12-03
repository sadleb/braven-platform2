class Rise360ModulePolicy < ApplicationPolicy
  def show?
    !!user
  end
end
