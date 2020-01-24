# This represents a project that you must submit or turn in
# some sort of artifact. E.g. a file, an open ended answer,
# a URL, or even a collection of answers or inputs that you
# enter into HTML input fields.
#
# Note: these were called assignments in the old Portal code.
class Project < ApplicationRecord
  has_many :project_submissions
  has_many :users, :through => :project_submissions
  belongs_to :course_module
  
  alias_attribute :submissions, :project_submissions

  # TODO: group projects? A project where there is one submission for
  # a group of people and they all get the same grade.

  validates :name, presence: true
end
