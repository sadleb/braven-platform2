class ProjectSubmission < ApplicationRecord
  belongs_to :user
  belongs_to :base_course_project_version, foreign_key: "base_course_custom_content_version_id"
  has_one :rubric_grade
  has_one :course, through: :base_course_project_version, source: :base_course, class_name: 'Course'
  has_one :project_version, through: :base_course_project_version, source: :custom_content_version, class_name: 'ProjectVersion'

  def project
    project_version.project
  end
end
