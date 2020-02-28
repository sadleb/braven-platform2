# This represents the grade given for a rubric row using guidance from
# the ratings defined and how many points should be awarded depending on how
# well the project submission meets expectations.
class RubricRowGrade < ApplicationRecord
  belongs_to :rubric_grade
  belongs_to :rubric_row

  validates :points_given, presence: true
end
