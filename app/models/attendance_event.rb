# This represents an event that a Fellow attends during the Accelerator course
# where attendance is taken. For example: a Learning Lab, or a one-on-one with
# their LC.
class AttendanceEvent < ApplicationRecord
  validates :title, presence: true
end
