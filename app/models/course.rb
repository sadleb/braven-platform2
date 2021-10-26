class Course < ApplicationRecord
  belongs_to :course_resource, optional: true

  scope :launched_courses, -> { where is_launched: true }
  scope :unlaunched_courses, -> { where is_launched: false }

  has_many :sections

  has_many :course_rise360_module_versions
  has_many :rise360_module_versions, :through => :course_rise360_module_versions

  has_many :course_custom_content_versions
  has_many :custom_content_versions, :through => :course_custom_content_versions

  # These are the published versions of project and survey content associated with this course.
  # Note: they are not the actual join table records from Course to ProjectVersion or SurveyVersion
  has_many :project_versions, -> { project_versions }, through: :course_custom_content_versions, source: :custom_content_version, class_name: 'ProjectVersion'
  has_many :survey_versions, -> { survey_versions }, through: :course_custom_content_versions, source: :custom_content_version, class_name: 'SurveyVersion'

  # These are the actual join table records the represent a published ProjectVersion or SurveyVersion
  # to a particular Course
  has_many :course_project_versions, -> { course_project_versions }, class_name: 'CourseProjectVersion'
  has_many :course_survey_versions, -> { course_survey_versions }, class_name: 'CourseSurveyVersion'

  has_many :course_attendance_events
  has_many :attendance_events, :through => :course_attendance_events

  before_validation do
    name.strip!
  end

  validates :name, presence: true

  # Enforce full 18-char Salesforce IDs to make querying reliable.
  validates :salesforce_program_id, length: {is: 18}, allow_blank: true

  def to_show
    attributes.slice('name')
  end

  # A Course Template is a Course that has not been launched. Templates are meant for Designers
  # to iterate on and then launch running courses from. Once it's launched, we need to be more
  # careful with what is allowed since actual users may have already used it and done work.
  def is_template?
    !is_launched
  end

  def rise360_modules
    rise360_module_versions.map { |m| m.rise360_module }
  end

  def custom_contents
    custom_content_versions.map { |v| v.custom_content }
  end

  def projects
    project_versions.map { |v| v.project }
  end

  def surveys
    survey_versions.map { |v| v.survey }
  end

  def canvas_url
    "#{Rails.application.secrets.canvas_url}/courses/#{canvas_course_id}"
  end

  def canvas_rubrics_url
    "#{Rails.application.secrets.canvas_url}/courses/#{canvas_course_id}/rubrics"
  end
end
