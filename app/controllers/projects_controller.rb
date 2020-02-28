class ProjectsController < ApplicationController
  include DryCrud::Controllers::Nestable

  nested_resource_of GradeCategory

  # GET /projects
  # GET /projects.json
  def index
  end

  # GET /projects/1
  # GET /projects/1.json
  def show
  end

  private

end
