# This policy always checks to see whether the user is logged-in.
# This policy also determines whether you can see all ProjectSubmissionAnswers
# attached to the ProjectSubmission.
class ProjectSubmissionPolicy < ApplicationPolicy
  attr_reader :user, :project_submission

  def initialize(user, project_submission)
    raise Pundit::NotAuthorizedError, "must be logged in" unless user
    raise Pundit::NotAuthorizedError, "no project submission specified" unless project_submission
    @user = user
    @project_submission = project_submission
  end

  # Permission to view a submission depends on two things:
  # 1. Can you view the ProjectVersion?
  # 2. Can you view the answers?
  def show?
    # 1. Can you view the ProjectVersion?
    return false unless ProjectVersionPolicy.new(user, project_submission.project_version).show?

    # 2. a.) Did you create this submission?
    return true if user == project_submission.user

    # 2. b.) Are you a TA for the person who created this submission?
    return true if user.ta_for?(project_submission.user)

    # 2. c.) Are you an admin?
    return true if user.admin?

    false
  end

  # The `new` action doesn't do much, so all you need is permission
  # to view the ProjectVersion.
  def new?
    ProjectVersionPolicy.new(user, project_submission.project_version).show?
  end

  # Permission to create/update a submission depends on two things:
  # 1. Can you view the ProjectVersion?
  # 2. Is this your submission?
  def create?
    return false unless ProjectVersionPolicy.new(user, project_submission.project_version).show?

    return true if user == project_submission.user

    false
  end

  def update?
    create?
  end

  def edit?
    create?
  end
end
