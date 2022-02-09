# frozen_string_literal: true

class AcceleratorSurveySubmissionPolicy < ApplicationPolicy

  def show?
    # Delegate to logic in the user model.
    return true if user&.can_access?(record)

    raise Pundit::NotAuthorizedError, message: ERROR_ENROLLMENT_SUBMISSION
  end

  def new?
    show?
  end

  def launch?
    show?
  end

  def create?
    # Only users enrolled as students can submit the form.
    # The LTIAdvantageAPI call to Canvas fails for all other enrollments.
    user.is_enrolled_as_student?(record&.course)
  end

  def completed?
    show?
  end
end
