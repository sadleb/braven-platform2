# frozen_string_literal: true

# This is a join table because there are multiple AttendanceEvents in a Course
# and the Events and be in multiple courses.
# Conceptually, this is a Canvas assignment for an AttendanceEvent.
class CourseAttendanceEvent < ApplicationRecord
  belongs_to :course
  belongs_to :attendance_event

  validates :course, :attendance_event, :canvas_assignment_id, presence: true

  # Sort names with numbers correctly.
  # From https://stackoverflow.com/a/25042119/12432170.
  scope :order_by_title, -> {
    sort_by{ |e|
      e.attendance_event.title.gsub(/\d+/) { |s|
        # Left-pad numbers with zeroes.
        # 8 is arbitrarily longer than the numbers we'll see in titles.
        "%08d" % s.to_i
      }
    }
  }

  def canvas_url
    "#{Rails.application.secrets.canvas_url}/courses/#{course.canvas_course_id}/assignments/#{canvas_assignment_id}"
  end
end
