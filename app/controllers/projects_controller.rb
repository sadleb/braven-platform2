# frozen_string_literal: true

class ProjectsController < ApplicationController
  include DryCrud::Controllers::Nestable
  include LtiHelper

  layout 'lti_placement'

  before_action :set_lti_launch, only: [:create]
  before_action :set_custom_content, only: [:create]

  skip_before_action :verify_authenticity_token, only: [:create], if: :is_sessionless_lti_launch?

  def show
    authorize @project
    @custom_content_version = @project.custom_content_version
  end

  # Create a Project for an LTI assignment placement
  def create
    @project = Project.new
    authorize @project

    # Create a new version for the project
    @custom_content.save_version!(current_user)
    @project.custom_content_version = @custom_content.last_version
    @project.save!

    # Create a project submission URL tied to this project
    # TODO: https://app.asana.com/0/1174274412967132/1186960110311121
    # Use the project submission URL, e.g.:
    # project_submission_url = new_project_project_submission_url(
    #   project_id: @project.id,
    # )
    project_submission_url = custom_content_custom_content_version_url(
      @project.custom_content_version.custom_content,
      @project.custom_content_version,
    )

    @deep_link_return_url, @jwt_response = helpers.lti_deep_link_response_message(@lti_launch, project_submission_url)
  end

  private
  def set_custom_content
    params.require(:custom_content_id)
    @custom_content = CustomContent.find(params[:custom_content_id])
  end
end
