class WaiverSubmissionPolicy < ApplicationPolicy

# TODO: make sure they are in the course this is being launched for.
# https://app.asana.com/0/1174274412967132/1199344732354185

  def launch?
    !!user
  end

  def new?
    !!user
  end

  def create?
    !!user
  end

  def completed?
    !!user
  end
end
