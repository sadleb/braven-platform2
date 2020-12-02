class ProjectSubmission < ApplicationRecord
  belongs_to :user
  belongs_to :course_project_version, foreign_key: "course_custom_content_version_id"
  has_one :rubric_grade
  has_one :course, through: :course_project_version
  has_one :project_version, through: :course_project_version, source: :custom_content_version, class_name: 'ProjectVersion'

  def project
    project_version.project
  end
end
