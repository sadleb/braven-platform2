
# This is an Impact Survey submission. 
# Unlike all the other Survey and Projet code, SurveySubmissions does **not**
# use single-table inheritance.
# This is because we have an impact survey-only key-value table that stores
# the responses.
class SurveySubmission < ApplicationRecord
  belongs_to :user
  belongs_to :base_course_custom_content_version

  has_one :course, through: :base_course_custom_content_version, source: :base_course, class_name: 'Course'
  has_one :survey_version, through: :base_course_custom_content_version, source: :custom_content_version, class_name: 'SurveyVersion'

  def survey
    survey_version.survey
  end
end
