class ProjectSubmission < ApplicationRecord
  belongs_to :user
  belongs_to :project
  has_one :rubric_grade

  # Example Usage: 
  # submissions = ProjectSubmission.for_projects_and_user(grade_category.projects, user)
  scope :for_projects_and_user, ->(ps, u) { where(project: ps, user: u) }

end
