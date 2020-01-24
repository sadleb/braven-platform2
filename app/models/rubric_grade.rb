# This represents the grade given for a project submission using a rubric.
# It is the collection of grades chosen for each row using guidance from
# the ratings defined for the row.
class RubricGrade < ApplicationRecord
  belongs_to :project_submission
  belongs_to :rubric
  has_many :rubric_row_grades
end
