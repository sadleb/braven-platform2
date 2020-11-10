# Represents a model joining a BaseCourse to a SurveyVersion
class BaseCourseSurveyVersion < BaseCourseCustomContentVersion
  belongs_to :survey_version, foreign_key: "custom_content_version_id"
end
