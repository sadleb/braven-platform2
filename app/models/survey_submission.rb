# This is an Impact Survey submission. 
# Unlike all the other Survey and Projet code, SurveySubmissions does **not**
# use single-table inheritance.
# This is because we have an impact survey-only key-value table that stores
# the responses.
class SurveySubmission < ApplicationRecord
  belongs_to :user
  belongs_to :course_survey_version, foreign_key: "course_custom_content_version_id"

  has_many :survey_submission_answers
  alias_attribute :answers, :survey_submission_answers

  has_one :course, through: :course_survey_version
  has_one :survey_version, through: :course_survey_version, source: :custom_content_version, class_name: 'SurveyVersion'

  def survey
    survey_version.survey
  end

  # Takes a hash of input_name (string) => input_value (string) and adds them
  # as SurveySubmissionAnswers to this submission
  def save_answers!(input_values_by_name)
    transaction do
      input_values_by_name.map do |input_name, input_value|
        SurveySubmissionAnswer.create!(
          survey_submission: self,
          input_name: input_name,
          input_value: input_value,
        )
      end
      save!
    end
  end
end
