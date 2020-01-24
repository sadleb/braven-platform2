# A CourseModule is a collection of related things to do as a unit.
# E.g. a lesson and a project and a survey that are all related
# to the topic of the first week of class.
class CourseModule < ApplicationRecord
  
  belongs_to :program
  has_many :projects
  has_many :lessons

  validates :name, presence: true

  def grade_for(user)
    ::GradeCalculator.grade_for_module(user, self)
  end
  
end
