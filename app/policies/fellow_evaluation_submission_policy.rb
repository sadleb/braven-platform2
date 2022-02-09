class FellowEvaluationSubmissionPolicy < ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    raise Pundit::NotAuthorizedError, "must be logged in" unless user
    raise Pundit::NotAuthorizedError, "no submission specified" unless record
    @user = user
    @record = record
  end

  # Admins can always see the "thank you for submitting" #show page.
  # This might be weird, so revisit if we decide we don't want this.
  def show?
    # Delegate to logic in the user model.
    return true if user.can_access?(record)

    raise Pundit::NotAuthorizedError, message: ERROR_ENROLLMENT_SUBMISSION
  end

  def new?
    # Admins can always submit capstone evaluations.
    # This might be weird, so revisit if we decide we don't want this.
    show?
  end

  def create?
    # Only users enrolled as students can submit the form.
    # The LTIAdvantageAPI call to Canvas fails for all other enrollments.
    user.is_enrolled_as_student?(record.course)
  end
end
