class ProjectSubmissionsController < ApplicationController
  before_action :set_project_submission, only: [:show]

  # GET /project_submissions
  # GET /project_submissions.json
  def index
    @project_submissions = params[:project_id] ? ProjectSubmission.where(project_id: params[:project_id]) :  ProjectSubmission.all
  end

  # GET /project_submissions/1
  # GET /project_submissions/1.json
  def show
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_project_submission
    @project_submission = ProjectSubmission.find(params[:id])
  end
end
