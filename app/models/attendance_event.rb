# This represents an event that a Fellow attends during the Accelerator course
# where attendance is taken. For example: a Learning Lab, or a one-on-one with
# their LC.
class AttendanceEvent < ApplicationRecord
  validates :title, presence: true

  # Type constants. Controls view behavior.
  STANDARD_EVENT = :StandardEvent
  SIMPLE_EVENT = :SimpleEvent

  # For use with Publishable in CourseAttendanceEventsController
  include Versionable

  # For Versionable
  # We don't version attendance events because the only content is the title,
  # which is stored in Canvas independent of our DB.
  def create_version!(user)
    self
  end
end
