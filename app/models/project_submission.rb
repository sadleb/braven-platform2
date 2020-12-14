class ProjectSubmission < ApplicationRecord
  belongs_to :user
  belongs_to :course_project_version, foreign_key: "course_custom_content_version_id"
  has_many :project_submission_answers
  alias_attribute :answers, :project_submission_answers
  has_one :rubric_grade
  has_one :course, through: :course_project_version
  has_one :project_version, through: :course_project_version, source: :custom_content_version, class_name: 'ProjectVersion'

  validates :user, :course_project_version, presence: true

  # There can only be one unsubmitted submission for each project/user.
 validates :course_custom_content_version_id, unless: -> { is_submitted },
    uniqueness: { scope: :user, conditions: -> { where.not(is_submitted: true) } }

  # Never change records that have been submitted.
  before_update :readonly!, if: -> { is_submitted }

  def project
    project_version.project
  end

  def save_answers!
    transaction do
      save!
      # Mark as submitted and set the uniqueness_condition to NULL
      # at the same time, so our uniqueness constraint works.
      update!(is_submitted: true, uniqueness_condition: nil)

      # Immediately copy all answers to a new unsubmitted submission.
      new_submission = ProjectSubmission.create!(
        user: user,
        course_project_version: course_project_version,
        is_submitted: false,
      )
      answers.each do |answer|
        new_answer = answer.dup
        new_answer.project_submission = new_submission
        new_answer.save!
      end
    end
  end
end
