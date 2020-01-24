# This represents a single cell in a rubric row where the grader is
# given guidance on the points to award for this row based on how well
# the project submission satisfies the row's criterion. A "rating"
# defines the things to look for and the points that should be awarded
# if the submission satisfies those.
class RubricRowRating < ApplicationRecord
  belongs_to :rubric_row
  has_many :rubric_row_grades

  validates :description, :points_value, presence: true

  # TODO: add a sort where row_ratings show up in high to low order of their points_value within a row.

end
