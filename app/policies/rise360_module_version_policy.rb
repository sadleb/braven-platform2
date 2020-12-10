class Rise360ModuleVersionPolicy < ApplicationPolicy
  def show?
    !!user
  end
end
