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

  has_many :lesson_submissions
  has_many :users, :through => :lesson_submissions
  belongs_to :course_module

  alias_attribute :submissions, :lesson_submissions

  validates :name, presence: true
end
