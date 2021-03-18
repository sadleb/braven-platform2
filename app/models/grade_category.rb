# A GradeCategory groups various things that are graded,
# like rise360_module_versions and projects, into a category where collectively
# everything in that category counts as X percent of your final grade.
class GradeCategory < ApplicationRecord
  
  belongs_to :course
  has_many :projects

  validates :name, presence: true
  validates :percent_of_grade, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }

  def grade_for(user)
    ::GradeCalculator.grade_for_category(user, self)
  end
  
end
