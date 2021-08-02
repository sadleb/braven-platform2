# frozen_string_literal: true

class AttendanceEventSubmissionPolicy < ApplicationPolicy

  # Note: For #launch, record can either be a Course or AttendanceEventSubmission
  def initialize(user, record)
    raise Pundit::NotAuthorizedError, "must be logged in" unless user
    raise Pundit::NotAuthorizedError, "no course/submission specified" unless record
    @user = user
    @record = record
  end

  def launch?
    return true if user.admin?

    # Is the user a TA in any section in the course?
    course = record.instance_of?(Course) ? record : record.course
    course.sections.each do |section|
      return true if user.has_role? RoleConstants::TA_ENROLLMENT, section
    end

    # This message will show up in the errors#not_authorized view.
    raise Pundit::NotAuthorizedError, message: 'You do not have permission to take attendance for this course.'
  end

  def edit?
    launch?
  end

  def update?
    launch?
  end
end
