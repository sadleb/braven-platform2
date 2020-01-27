class Program < ApplicationRecord
  has_many :program_memberships
  has_many :users, through: :program_memberships
  has_many :roles, through: :program_memberships


  # PROPOSAL: as we model this out, here is goal I want to propose:
  # Divorce the logic of how a "course" is laid out including what content, projects, lessons
  # grading rules, etc from the logic needed to actually execute a course and the logistics 
  # inolved in running it. E.g. the people in it, their role, the due dates, the submissions,
  # etc. 
  # 
  # We shouldn't have to copy everything over and over again when it's the same "course."
  # A "program" should just point to a course and have all the administration / logistics
  # tied to the program. So a program is an "instance" of a course that we are executing for
  # a given semester at a given school. 

  validates :name, presence: true, uniqueness: {case_sensitive: false}
  
  def to_show
    attributes.slice('name')
  end
end
