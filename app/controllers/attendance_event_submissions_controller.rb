# frozen_string_literal: true

class AttendanceEventSubmissionsController < ApplicationController
  include DryCrud::Controllers
  
  # For the #launch action
  include LtiHelper
  before_action :set_lti_launch, only: [:launch]
  before_action :set_course_attendance_event, only: [:launch]

  layout 'lti_canvas'

  def launch
    # TODO: Update this to authorize @attendance_event_submission when we
    # add the model in the next PR
    authorize @course_attendance_event, :launch?
    @attendance_event = @course_attendance_event.attendance_event
  end

private
  # For #launch
  def set_course_attendance_event
    @course_attendance_event = CourseAttendanceEvent.find_by(
      canvas_assignment_id: @lti_launch.request_message.custom['assignment_id'],
    )
  end
end
