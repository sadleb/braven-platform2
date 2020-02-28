# This represents a project that you must submit or turn in
# some sort of artifact. E.g. a file, an open ended answer,
# a URL, or even a collection of answers or inputs that you
# enter into HTML input fields.
#
# Note: these were called assignments in the old Portal code.
class Project < ApplicationRecord
  belongs_to :grade_category 
  has_many :project_submissions
  has_many :users, :through => :project_submissions
  has_one :rubric
 
  alias_attribute :submissions, :project_submissions

  # TODO: group projects? A project where there is one submission for
  # a group of people and they all get the same grade.

  validates :name, :points_possible, presence: true
  validates :percent_of_grade_category, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
end
