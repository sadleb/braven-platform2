class ProjectsController < ApplicationController
  before_action :set_project, only: [:show]

  # GET /projects
  # GET /projects.json
  def index
    @projects = params[:course_module_id] ? Project.where(course_module_id: params[:course_module_id]) : Project.all
  end

  # GET /projects/1
  # GET /projects/1.json
  def show
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_project
    @project = Project.find(params[:id])
  end
end
