class Rise360ModuleGradePolicy < ApplicationPolicy
  attr_reader :user, :rise360_module_grade

  def initialize(user, rise360_module_grade)
    raise Pundit::NotAuthorizedError, "must be logged in" unless user
    raise Pundit::NotAuthorizedError, "no Rise360ModuleGrade specified" unless rise360_module_grade
    @user = user
    @rise360_module_grade = rise360_module_grade
  end

  def show?
    # Admins can always see grades
    return true if user.admin?

    # Can you view the Rise360ModuleVersion?
    return false unless Rise360ModuleVersionPolicy.new(
      user, rise360_module_grade.course_rise360_module_version.rise360_module_version
    ).show?

    # Is it your own grade?
    return true if user == rise360_module_grade.user

    # Are you a TA for the person who created this submission?
    return true if user.can_view_submission_from?(
      rise360_module_grade.user,
      rise360_module_grade.course_rise360_module_version.course
    )

    false
  end

  # Call something like the following to get all Rise360ModuleInteractions
  # relevant to this grade:
  #  @interactions = policy_rise360_module_grade(@rise360_module_grade)
  class Scope
    attr_reader :user, :rise360_module_grade

    def initialize(user, rise360_module_grade)
      @user = user
      @rise360_module_grade = rise360_module_grade
    end

    def resolve
      Rise360ModuleInteraction.where(
        user: @rise360_module_grade.user,
        canvas_assignment_id: @rise360_module_grade.course_rise360_module_version.canvas_assignment_id
      )
    end
  end

end
