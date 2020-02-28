# This represents a category within a rubric where are rows in this
# category are related to the same overarching concept.
class RubricRowCategory < ApplicationRecord
  has_many :rubric_rows
  belongs_to :rubric

  validates :name, :position, presence: true
end
