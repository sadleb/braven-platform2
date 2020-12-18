# Represents a model joining a Course to a SurveyVersion
class CourseSurveyVersion < CourseCustomContentVersion
  belongs_to :survey_version, foreign_key: "custom_content_version_id"
  has_one :survey, through: :survey_version

  def new_submission_url
    new_course_survey_version_survey_submission_url(
      self,
      protocol: 'https',
    )
  end
end
