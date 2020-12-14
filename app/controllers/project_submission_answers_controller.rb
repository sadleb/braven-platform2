
class ProjectSubmissionAnswersController < ApplicationController
  include LtiHelper
  include DryCrud::Controllers::Nestable

  nested_resource_of ProjectSubmission

  skip_before_action :verify_authenticity_token, only: [:create], if: :is_sessionless_lti_launch?

  def index
    # Read access to answers is determined by read access to the submission.
    # We don't use a Pundit scope because this is a nested resource and Pundit
    # scopes assume you're doing something like `Model.all`, not `parent.children`.
    authorize @project_submission, :show?

    @project_submission_answers = @project_submission.answers
  end

  def create
    # Infer from ProjectSubmissionPolicy, because we aren't guaranteed to have an
    # answer object until it's already saved in the DB, at which point it's too
    # late to check permissions.
    authorize @project_submission

    ProjectSubmissionAnswer.update_or_create_by!(
      project_submission: @project_submission,
      input_name: create_params[:input_name],
      input_value: create_params[:input_value],
    )
  end

private

  def create_params
    params.require(:project_submission_answer).permit(:input_name, :input_value)
  end
end
