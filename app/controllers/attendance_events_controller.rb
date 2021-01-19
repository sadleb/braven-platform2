# frozen_string_literal: true

class AttendanceEventsController < ApplicationController
  include DryCrud::Controllers

  layout 'admin'

  def index
    authorize AttendanceEvent
    @attendance_events = AttendanceEvent.all.order(title: :desc)
  end

  def new
    @attendance_event = AttendanceEvent.new
    authorize @attendance_event
  end

  def create
    @attendance_event = AttendanceEvent.new
    authorize @attendance_event
    @attendance_event.update!(title: create_params[:title])

    respond_to do |format|
      format.html { redirect_to(
        attendance_events_path,
        notice: 'Attendance event was successfully created.'
      ) }
      format.json { head :no_content }
    end
  end

  # Note: We do **not** support #edit and #update currently.
  # If we do, we also need to support the corresponding #publish_latest
  # action for the CourseAttendanceEventsController so there's a way to update
  # the Canvas assignment title reflect the change.

  def destroy
    authorize @attendance_event
    @attendance_event.destroy!
    respond_to do |format|
      format.html { redirect_to(
        attendance_events_path,
        notice: 'Attendance event was successfully deleted.',
      ) }
      format.json { head :no_content }
    end
  end

private
  def create_params
    params.require(:attendance_event).permit(:title)
  end
end
