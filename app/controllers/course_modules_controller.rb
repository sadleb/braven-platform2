class CourseModulesController < ApplicationController
  include DryCrud::Controllers::Nestable

  nested_resource_of Program

  # GET /course_modules
  # GET /course_modules.json
  def index
  end

  # GET /course_modules/1
  # GET /course_modules/1.json
  def show
  end

  private

end
