class CustomContentVersion < ApplicationRecord
  belongs_to :custom_content
  belongs_to :user

  has_many :course_custom_content_versions
  has_many :courses, through: :course_custom_content_versions

  has_many :courses, through: :course_custom_content_versions

  scope :project_versions, -> { where type: 'ProjectVersion' }
  scope :survey_versions, -> { where type: 'SurveyVersion' }
end
