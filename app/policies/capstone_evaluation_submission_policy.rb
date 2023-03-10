class CapstoneEvaluationSubmissionPolicy < ApplicationPolicy
  def initialize(user, record)
    raise Pundit::NotAuthorizedError, "must be logged in" unless user
    raise Pundit::NotAuthorizedError, "no submission specified" unless record
    @user = user
    @record = record
  end

  def launch?
    return true if user.admin?

    course = record.instance_of?(Course) ? record : record.course
    return false if course.nil?
    return true if user.is_enrolled_as_student?(course)

    raise Pundit::NotAuthorizedError, message: 'Only admin and fellows can view this page to see their grades or to publish them.'
  end

  def show?
    # Delegate to logic in the user model.
    return true if user.can_access?(record)

    raise Pundit::NotAuthorizedError, message: ERROR_ENROLLMENT_SUBMISSION
  end

  # Admins can always submit capstone evaluations.
  # This might be weird, so revisit if we decide we don't want this.
  def new?
    show?
  end

  def create?
    # Only users enrolled as students can submit the form.
    # The LTIAdvantageAPI call to Canvas fails for all other enrollments.
    user.is_enrolled_as_student?(record.course)
  end

  def score?
    return true if user.admin?
  end
end
