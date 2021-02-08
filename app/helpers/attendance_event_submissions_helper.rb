# frozen_string_literal: true

module AttendanceEventSubmissionsHelper
  def get_default_course_attendance_event(section)
    event_by_date = SelectAttendanceEventByDate.new(
      @accelerator_course,
      current_user,
      section,
    ).run()
    event_by_date || @accelerator_course.course_attendance_events.order_by_title.first
  end
end
