# This represents, well, a lesson. It's learning content meant to
# teach. It's interactive and the user must engage in the content
# by being asked questions and answering, some of which they
# must get correct. It can be auto-graded for both participation
# and engagement as well as for mastery questions, the ones they
# must get correct to get credit for.
#
# Note: we called these "modules" in everyday language in the old Portal
# and they were WikiPages in the code with the retained_data functionality
# tacked on top.
class Lesson < ApplicationRecord
  belongs_to :grade_category 
  has_many :lesson_submissions
  has_many :users, :through => :lesson_submissions

  alias_attribute :submissions, :lesson_submissions

  validates :name, :points_possible, presence: true
  validates :percent_of_grade_category, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
end
