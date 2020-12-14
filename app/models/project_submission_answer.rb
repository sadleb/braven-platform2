# Support multiple submissions, but only one draft.
class ProjectSubmissionAnswer < ApplicationRecord
  belongs_to  :project_submission
  has_one :user, through: :project_submission
  has_one :course_project_version, through: :project_submission

  validates :input_name, uniqueness: { scope: :project_submission_id }
  validates :project_submission, :input_name, presence: true
  validate :project_submission_not_already_submitted

  def self.update_or_create_by!(project_submission:, input_name:, input_value:)
    transaction do
      # Note that there is a race condition with other threads since this does a find
      # before a create. Because of the uniqueness constraint (db level), the second one will fail
      # which is what we want. We can't use `create_or_find_by!` which doesn't have this
      # race condition b/c then we can't use a uniqueness constraint. ProjectSubmission has this same
      # issue.
      answer = find_or_create_by!(
        project_submission: project_submission,
        input_name: input_name,
      )
      answer.update!(input_value: input_value)
    end
  end

private

  def project_submission_not_already_submitted
    if project_submission&.is_submitted
      errors.add :project_submission, "cannot already be submitted"
    end
  end
end
