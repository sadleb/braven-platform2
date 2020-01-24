class CourseModulesController < ApplicationController
  before_action :set_course_module, only: [:show]

  # GET /course_modules
  # GET /course_modules.json
  def index
    @course_modules = params[:program_id] ? CourseModule.where(program_id: params[:program_id]) : CourseModule.all
  end

  # GET /course_modules/1
  # GET /course_modules/1.json
  def show
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_course_module
    @course_module = CourseModule.find(params[:id])
  end
end
