class BaseCourseCustomContentVersion < ApplicationRecord

  include Rails.application.routes.url_helpers

  MissingCanvasAssignmentIdError = Class.new(StandardError)

  belongs_to :base_course
  belongs_to :custom_content_version

  validates :base_course, :custom_content_version, presence: true
  validates :base_course, uniqueness: { scope: :custom_content_version }

  has_many :project_submissions
  has_many :survey_submissions

  has_many :users, :through => :project_submissions
  alias_attribute :submissions, :project_submissions
  
  scope :base_course_project_versions, -> { where type: 'BaseCourseProjectVersion' }
  scope :base_course_survey_versions, -> { where type: 'BaseCourseSurveyVersion' }

  def publish_latest!(user)
    transaction do
      # We don't need to update the assignment in Canvas when we update the version,
      # but we need to check that that assignment still exists (e.g., it wasn't deleted
      # in Canvas and not through our Course Management page) so we don't fail silently
      # (e.g., we think we're updating an assignment, but nothing's changing in Canvas).
      CanvasAPI.client.get_assignment(
        base_course.canvas_course_id,
        canvas_assignment_id,
      )
      update!(custom_content_version: custom_content_version.custom_content.save_version!(user))
    end
  end

  # This does a destroy! and also deletes the Canvas assignment from the Canvas course.
  def remove!
    begin
      transaction do
        # The order here is important.
        # We only delete from Canvas iff we can destroy! the model because it
        # is more difficult to re-create the Canvas assignment if we delete it
        # first and later fail updating our model in destroy!.
        destroy!
        CanvasAPI.client.delete_assignment(
          base_course.canvas_course_id,
          canvas_assignment_id,
        )
      end
    rescue RestClient::NotFound
      # This gets thrown when the assignment doesn't exist in Canvas.
      # It's fine to delete the record from our DB in this case.
      destroy!
    end
  end

  def new_submission_url
    new_polymorphic_url([self, submission_type.new], protocol: 'https')
  end

  def canvas_url
    # TODO: add a validation and make the column constraint be non-null.
    # https://app.asana.com/0/1174274412967132/1198965066699365
    raise MissingCanvasAssignmentIdError, "BaseCourseCustomContentVersion[#{inspect}] has no canvas_assignment_id" unless canvas_assignment_id
    "#{Rails.application.secrets.canvas_url}/courses/#{base_course.canvas_course_id}/assignments/#{canvas_assignment_id}"
  end

  # Finds an existing BaseCourseCustomContentVersion by parsing the URL for one.
  def self.find_by_lti_launch_url(url)
    project_id = url[/.*\/base_course_project_versions\/(\d+)/, 1]
    return BaseCourseProjectVersion.find(project_id) if project_id
    survey_id = url[/.*\/base_course_survey_versions\/(\d+)/, 1]
    return BaseCourseSurveyVersion.find(survey_id) if survey_id
    nil # This could be an Lti Launch URL for something else (like a different LTI extension) which we ignore
  end

  private
  def submission_type
    case custom_content_version.type
    when 'ProjectVersion'
      ProjectSubmission
    when 'SurveyVersion'
      SurveySubmission
    end
  end
end
