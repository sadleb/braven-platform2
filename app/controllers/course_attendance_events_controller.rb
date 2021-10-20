# frozen_string_literal: true

class CourseAttendanceEventsController < ApplicationController
  include DryCrud::Controllers::Nestable
  nested_resource_of Course

  # Adds the #publish, #unpublish actions
  include Publishable
  prepend_before_action :set_model_instance, only: [:unpublish]

  layout 'admin'

  ATTENDANCE_EVENT_POINTS_POSSIBLE = 10.0

  def new
    authorize CourseAttendanceEvent
    @attendance_events = AttendanceEvent.all - @course.attendance_events
  end

private
  # For Publishable
  def assignment_name
    @course_attendance_event.attendance_event.title
  end

  def points_possible
    ATTENDANCE_EVENT_POINTS_POSSIBLE
  end

  def lti_launch_url
    launch_attendance_event_submission_answers_url(protocol: 'https')
  end

  # Override this setting so that the CLASS assignment is iframed in Canvas.
  # We show the Zoom link for that class and it's a bad UX to require them to
  # launch this in a new tab just to access the link. This only works b/c
  # we add the state parameter into the URL and don't rely on cookies or the
  # redirect Location path for the launch_attendance_event_submission_answers_url
  # in app/controllers/lti_launch_controller.rb
  def open_in_new_tab
    false
  end

  # Note: The versioning here is faked by AttendanceEvent
  def versionable_instance
    AttendanceEvent.find(params[:attendance_event_id])
  end

  def version_name
    'attendance_event'
  end
end
