# This represents a rubric used to grade a project.
class Rubric < ApplicationRecord
  has_many :rubric_row_categories
  has_many :rubric_rows, :through => :rubric_row_categories
  belongs_to :project

  validates :points_possible, presence: true
end
