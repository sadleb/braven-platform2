# frozen_string_literal: true

# You can think of this as representing a Canvas assignment to show a Rise360Module.
# It joins the Course to the published version of the Rise360Module
class CourseRise360ModuleVersion < ApplicationRecord
  belongs_to :course
  belongs_to :rise360_module_version
  has_one :rise360_module, :through => :rise360_module_version
  has_many :rise360_module_grades

  validates :canvas_assignment_id, presence: true
  validates :course, :rise360_module_version, presence: true
  validates :course, uniqueness: { scope: :rise360_module_version }

  def canvas_url
    "#{Rails.application.secrets.canvas_url}/courses/#{course.canvas_course_id}/assignments/#{canvas_assignment_id}"
  end

  # Returns true if there is any student data that references this instance.
  # Ignores whether there is data done by folks with a different role; like a TA
  # Teacher, or Designer.
  #
  # Anytime a student (Fellow) opens a Module, a Rise360ModuleGrade record is created.
  # It's overkill to check the states and interactions as well. See:
  # rise360_module_versions_controller#ensure_submission()
  def has_student_data?
    rise360_module_grades.present?
  end

  # The list of Users who are students that have opened this Module in Canvas
  # and therefore have associated data.
  def students_with_data
    User.where(id: rise360_module_grades.pluck(:user_id))
  end
end
