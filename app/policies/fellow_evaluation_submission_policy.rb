class FellowEvaluationSubmissionPolicy < ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    raise Pundit::NotAuthorizedError, "must be logged in" unless user
    raise Pundit::NotAuthorizedError, "no submission specified" unless record
    @user = user
    @record = record
  end

  def show?
    # Admins can always see the "thank you for submitting" #show page.
    # This might be weird, so revisit if we decide we don't want this.
    return true if user.admin?

    # This is your submission
    user == record.user
  end

  def new?
    # Admins can always submit peer reviews.
    # This might be weird, so revisit if we decide we don't want this.
    return true if user.admin?

    # Anyone enrolled can see the peer review form
    return true if is_enrolled?

    false
  end

  def create?
    # Only users enrolled as students can submit the form.
    # The LTIAdvantageAPI call to Canvas fails for all other enrollments.
    record.course.sections.each do |section|
      return true if user.has_role? RoleConstants::STUDENT_ENROLLMENT, section
    end

    false
  end

private
  # TODO: refactor and use EnrolledPolicy here
  # https://app.asana.com/0/1174274412967132/1199344732354185
  # Returns true iff user has any type of enrollment in any section of course
  def is_enrolled?
    record.course.sections.each do |section|
        RoleConstants::SECTION_ROLES.each do |role|
          return true if user.has_role? role, section
        end
    end
    false
  end
end
