class CourseAttendanceEventPolicy < ApplicationPolicy
  def publish?
    edit?
  end

  def unpublish?
    edit?
  end

  # TODO: Move this to AttendanceEventSubmission policy in the next PR
  def launch?
    return true if user&.is_enrolled?(record&.course)
    admin_message = 'Please Masquerade as someone to view this assignment as they would see it. ' if user.admin?
    raise Pundit::NotAuthorizedError, message: "#{admin_message}Only an Enrolled Participant can view this page and see their Zoom link."
  end
end
