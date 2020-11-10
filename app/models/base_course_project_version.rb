# Represents a model joining a BaseCourse to a ProjectVersion
class BaseCourseProjectVersion < BaseCourseCustomContentVersion
  belongs_to :project_version, foreign_key: "custom_content_version_id"
end
