class LrsXapiMockPolicy < ApplicationPolicy
  def xAPI?
    !!user
  end
end
