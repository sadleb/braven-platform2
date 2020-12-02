# Represents a model joining a Course to a SurveyVersion
class CourseSurveyVersion < CourseCustomContentVersion
  belongs_to :survey_version, foreign_key: "custom_content_version_id"
end
