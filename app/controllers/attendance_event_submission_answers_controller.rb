# frozen_string_literal: true
require 'salesforce_api'

# Represents the attendance answer (aka attendance status) submitted for a
# Fellow (student) for a given event (e.g. a Learning Lab). An
# AttendanceEventSubmission is a set of answers, one per Fellow.
#
# Note: we use "answer" to be consistent with the other submission controllers/models.
class AttendanceEventSubmissionAnswersController < ApplicationController
  include DryCrud::Controllers

  # For the #launch action
  include LtiHelper
  before_action :set_lti_launch, only: [:launch]
  before_action :set_course_attendance_event, only: [:launch]
  before_action :set_attendance_event, only: [:launch]
  before_action :set_event_name_display, only: [:launch]
  before_action :set_zoom_link, only: [:launch]

  layout 'lti_canvas'

  def launch
  end

private

  def set_course_attendance_event
    @course_attendance_event = CourseAttendanceEvent.find_by(
      canvas_assignment_id: @lti_launch.request_message.canvas_assignment_id,
    )
    authorize @course_attendance_event, :launch?
  end

  def set_attendance_event
    @attendance_event = @course_attendance_event.attendance_event
  end

  def set_event_name_display
    @event_name_display = @attendance_event.event_type_display
  end

  def set_zoom_link
    zoom_link_to_show = AttendanceEvent::ZOOM_MEETING_LINK_ATTRIBUTE_FOR[@attendance_event.event_type.to_sym]
    if zoom_link_to_show
      program_id = @course_attendance_event.course.salesforce_program_id
      participant = SalesforceAPI.client.find_participant(contact_id: current_user.salesforce_id, program_id: program_id)

      # Make it easier to debug and be extra defensive if values other than the three attributes
      # we're allowing to be dynamically sent to the struct in order to get the Zoom links are used.
      unless [:zoom_meeting_link_1, :zoom_meeting_link_2, :zoom_meeting_link_3].include?(zoom_link_to_show)
        raise ArgumentError.new("zoom_link_to_show=#{zoom_link_to_show} not supported")
      end

      # Note that this particular Participant may not have a Zoom link sync'd or uploaded for this
      # field which is fine. If it's nil the view just doesn't show a link.
      @zoom_meeting_link =  participant.send(zoom_link_to_show)
      Honeycomb.add_field("salesforce.participant.#{zoom_link_to_show}", @zoom_meeting_link.to_s)
    end
  end
end
