# Represents a model joining a Course to a ProjectVersion
class CourseProjectVersion < CourseCustomContentVersion
  belongs_to :project_version, foreign_key: "custom_content_version_id"

  has_one :project, through: :project_version

  def new_submission_url
    new_course_project_version_project_submission_url(
      self,
      protocol: 'https',
    )
  end
end
