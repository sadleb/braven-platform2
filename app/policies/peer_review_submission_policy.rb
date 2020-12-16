class PeerReviewSubmissionPolicy < ApplicationPolicy
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

    user == record.user
  end

  def new?
    # Admins can always submit peer reviews.
    # This might be weird, so revisit if we decide we don't want this.
    return true if user.admin?

    # Students can see and create peer reviews in courses where they are enrolled.
    record.course.sections.each do |section|
      return true if user.has_role? RoleConstants::STUDENT_ENROLLMENT, section
    end

    false
  end

  def create?
    # Admins can always submit peer reviews.
    # This might be weird, so revisit if we decide we don't want this.
    return true if user.admin?

    # Students can see and create peer reviews in courses where they are enrolled.
    record.course.sections.each do |section|
      return true if user.has_role? RoleConstants::STUDENT_ENROLLMENT, section
    end

    false
  end
end