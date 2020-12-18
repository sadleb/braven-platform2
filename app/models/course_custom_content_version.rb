class CourseCustomContentVersion < ApplicationRecord

  include Rails.application.routes.url_helpers

  belongs_to :course
  belongs_to :custom_content_version

  validates :canvas_assignment_id, presence: true
  validates :course, :custom_content_version, presence: true
  validates :course, uniqueness: { scope: :custom_content_version }

  has_many :project_submissions
  has_many :survey_submissions

  has_many :users, :through => :project_submissions
  alias_attribute :submissions, :project_submissions
  
  scope :course_project_versions, -> { where type: 'CourseProjectVersion' }
  scope :course_survey_versions, -> { where type: 'CourseSurveyVersion' }

  def canvas_url
    "#{Rails.application.secrets.canvas_url}/courses/#{course.canvas_course_id}/assignments/#{canvas_assignment_id}"
  end

  # Finds an existing CourseCustomContentVersion by parsing the URL for one.
  def self.find_by_lti_launch_url(url)
    project_id = url[/.*\/course_project_versions\/(\d+)/, 1]
    return CourseProjectVersion.find(project_id) if project_id
    survey_id = url[/.*\/course_survey_versions\/(\d+)/, 1]
    return CourseSurveyVersion.find(survey_id) if survey_id
    nil # This could be an Lti Launch URL for something else (like a different LTI extension) which we ignore
  end
end
