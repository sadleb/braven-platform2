class TestUserPolicy < ApplicationPolicy
  def post?
    create?
  end

  def cohort_schedules?
    index?
  end

  def cohort_sections?
    index?
  end

  def ta_assignments?
    index?
  end

  def get_program_tas?
    index?
  end
end
