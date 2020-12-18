# frozen_string_literal: true

class CourseRise360ModuleVersion < ApplicationRecord
  belongs_to :course
  belongs_to :rise360_module_version
  has_one :rise360_module, :through => :rise360_module_version

  validates :canvas_assignment_id, presence: true
  validates :course, :rise360_module_version, presence: true
  validates :course, uniqueness: { scope: :rise360_module_version }

  def canvas_url
    "#{Rails.application.secrets.canvas_url}/courses/#{course.canvas_course_id}/assignments/#{canvas_assignment_id}"
  end
end
