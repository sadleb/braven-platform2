class ProjectSubmissionsController < ApplicationController
  include DryCrud::Controllers::Nestable

  nested_resource_of Project

  # GET /project_submissions
  # GET /project_submissions.json
  def index
  end

  # GET /project_submissions/1
  # GET /project_submissions/1.json
  def show
  end

  private

end
