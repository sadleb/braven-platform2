# Represents a model joining a Course to a ProjectVersion
class CourseProjectVersion < CourseCustomContentVersion
  belongs_to :project_version, foreign_key: "custom_content_version_id"
end
