# This represents a row in a rubric where the project submission can
# get up to the max points possible determined using guidance from the
# ratings defined for this row.
#
# Note: This can also be referred to as a rubric criterion,
# but that's a mouthful.
class RubricRow < ApplicationRecord
  has_many :rubric_row_ratings
  belongs_to :rubric_row_category

  validates :criterion, :points_possible, :position, presence: true

end
