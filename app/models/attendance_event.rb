# This represents an event that a Fellow attends during the Accelerator course
# where attendance is taken. For example: a Learning Lab, or a one-on-one with
# their LC.
class AttendanceEvent < ApplicationRecord
  # For use with Publishable in CourseAttendanceEventsController
  include Versionable

  # Type constants. Controls view behavior.
  LEARNING_LAB = :learning_lab
  LEADERSHIP_COACH_1_1 = :leadership_coach_1_1
  ORIENTATION = :orientation

  # Hardcoded mapping of the above event_types to the attribute on SFParticipant
  # to pull the Zoom link from. Missing mappings means don't show a Zoom link.
  ZOOM_MEETING_LINK_ATTRIBUTE_FOR = {
    LEARNING_LAB => :zoom_meeting_link_1,
    ORIENTATION => :zoom_meeting_link_2,
  }

  validates :title, :event_type, presence: true
  validates :event_type, inclusion: { in: [LEARNING_LAB.to_s, LEADERSHIP_COACH_1_1.to_s, ORIENTATION.to_s],
    message: "%{value} is not a valid event_type" }

  has_many :course_attendance_events

  # The displayed value of the event_type in human readable format.
  # E.g. Learning Lab, Orientation, or Leadership Coach 1:1
  def event_type_display
    return @event_type_display if @event_type_display
    Honeycomb.add_field('attendance_event.event_type', event_type.to_s)
    @event_type_display = event_type.titleize
    @event_type_display.sub!('1 1', '1:1') # Turn "Leadership Coach 1 1" into "Leadership Coach 1:1"
    @event_type_display
  end

  # For Versionable
  # We don't version attendance events because the only content is the title,
  # which is stored in Canvas independent of our DB.
  def create_version!(user)
    self
  end
end
