# frozen_string_literal: true

class AcceleratorSurveySubmissionPolicy < ApplicationPolicy
  def new?
    # Admins can see the form
    return true if user.admin?

    # Anyone enrolled in the course can see the form
    return true if is_enrolled?

    false
  end

  def launch?
    new?
  end

  def create?
    # Only users enrolled as students can submit the form.
    # The LTIAdvantageAPI call to Canvas fails for all other enrollments.
    record.course.sections.each do |section|
      return true if user.has_role? RoleConstants::STUDENT_ENROLLMENT, section
    end

    false
  end

  def completed?
    # Admins can see submission confirmations for everyone
    return true if user.admin?

    # Fail early if you aren't enrolled in the course
    return false unless is_enrolled?

    # You can see your own submission confirmation
    return true if user == record.user

    # You can see a submission confirmation for a student who you're a TA for
    # TODO: https://app.asana.com/0/1168520191527013/1199512664295642
    # This need to be a specific check for the particular section of the course.
    return true if user.ta_for?(record.user)

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
