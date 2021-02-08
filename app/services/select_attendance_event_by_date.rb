# frozen_string_literal: true
require 'canvas_api'
require 'time'

# When taking attendance, we show a dropdown of AttendanceEvents
# that the user can choose from. This service is responsible for
# choosing the most likely event that they'll want to take attendance
# for given the current date.
#
# The algorithm basically boils down to "on the day of the event
# (aka midnight) start selecting that event instead of the previous one"
class SelectAttendanceEventByDate
  SelectAttendanceEventByDateError = Class.new(StandardError)

  def initialize(course, user, section, date=Time.now.utc)
    # Note that the times sent from Canvas are in UTC, so we need a Time object in
    # UTC so that the comparisons are apples to apples without a timezone mistake
    raise SelectAttendanceEventByDateError, "Must pass in a UTC Time object to compare against" unless date.utc?

    @course = course
    @user = user
    @section = section
    @date = date
  end

  def run()
    course_attendance_events = get_course_attendance_events_ordered_by_due_at()
    return nil if course_attendance_events.blank?

    if before_or_on?(course_attendance_events.first.due_at)
      return course_attendance_events.first
    elsif after_or_on?(course_attendance_events.last.due_at)
      return course_attendance_events.last
    end

    course_attendance_events.each_with_index do |event, index|
      # Short circuit if we find an event that is today. We always show
      # the first one of the day.
      return event if same_day_as?(event.due_at)

      # Scan until we're in between two events, then return the event in the
      # past which is the most recent one unless we've already crossed over to
      # the same day as the next one, which is when it switches to show the next.
      next_event = course_attendance_events[index+1]
      return event unless next_event # We're at the end
      next unless in_between?(event.due_at, next_event.due_at)
      return (same_day_as?(next_event.due_at) ? next_event : event)
    end

    # We should never get here
    raise SelectAttendanceEventByDateError, "Algorithm has a bug for @date = #{@date} and " \
                            "course_attendance_events = #{course_attendance_events.inspect}"
  end

private

  def get_course_attendance_events_ordered_by_due_at()
    return nil if @course.course_attendance_events.blank?

    # Get AssignmentOverride objects for the attendance events
    # Note: we use the user's sections and overrides because we need to access
    # the due dates, which depend on the section that the user is enrolled in
    overrides = CanvasAPI.client.get_assignment_overrides_for_section(
      @course.canvas_course_id,
      @section.canvas_section_id,
      @course.course_attendance_events.map(&:canvas_assignment_id),
    )

    # Set .due_at on each event. Assumes only one override per assignment b/c we
    # filter down to just the overrides for a section above.
    # Note: here is an example of the due_at string that Canvas sends: 2021-02-06T04:59:59Z
    # It's in UTC and Time.parse will have the UTC timezone associated with it. So the @date
    # that this service uses as "today" must also be in UTC.
    @course.course_attendance_events.each do |event|
      override = overrides
        .find { |override| override['assignment_id'] == event.canvas_assignment_id }
      event.due_at = override && override['due_at'] ? Time.parse(override['due_at']) : nil
    end

    # Filter out events without due dates and sort by due date
    course_attendance_events = @course.course_attendance_events
      .select { |event| event.due_at.present? }
      .sort_by &:due_at
  end

  def before_or_on?(other_date)
    return true if same_day_as?(other_date)
    return @date.before?(other_date)
  end

  def after_or_on?(other_date)
    return true if same_day_as?(other_date)
    return @date.after?(other_date)
  end

  def in_between?(date1, date2)
    return (@date.after?(date1) && @date.before?(date2))
  end

  def same_day_as?(other_date)
    return @date.beginning_of_day == other_date.beginning_of_day
  end
end
