class CourseAttendanceEventPolicy < ApplicationPolicy
  def publish?
    edit?
  end

  def unpublish?
    edit?
  end

  # TODO: Move this to AttendanceEventSubmission policy in the next PR
  def launch?
    return true if user.admin?
    is_enrolled?
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
