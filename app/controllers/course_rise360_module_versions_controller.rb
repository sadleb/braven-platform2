# frozen_string_literal: true

class CourseRise360ModuleVersionsController < ApplicationController
  include LtiHelper

  include DryCrud::Controllers::Nestable

  # Adds the #publish and #unpublish actions
  include Publishable
  nested_resource_of Course

  before_action :verify_can_edit!
  before_action :create, only: [:publish]
  before_action :destroy, only: [:unpublish]

  layout 'admin'

  def new
    authorize Rise360Module
    @modules = Rise360Module.all - @course.rise360_modules
  end

  def update
    authorize @course_rise360_module_version
    rise360_module = @course_rise360_module_version.rise360_module
    @course_rise360_module_version.update!(
      rise360_module_version: rise360_module.create_version!(@current_user),
    )

    respond_to do |format|
      format.html { redirect_to(
        edit_course_path(course),
        notice: message % { subject: assignment_name, verb: 'updated in' }
      ) }
      format.json { head :no_content }
    end
  end

private
  def create
    authorize CourseRise360ModuleVersion
    rise360_module = Rise360Module.find(params[:rise360_module_id])
    @course_rise360_module_version = CourseRise360ModuleVersion.create!(
      course: @course,
      rise360_module_version: rise360_module.create_version!(@current_user),
    )
  end

  def destroy
    @course_rise360_module_version = CourseRise360ModuleVersion.find(params[:id])
    authorize @course_rise360_module_version
    # For Publishable
    params[:canvas_assignment_id] = @course_rise360_module_version.canvas_assignment_id
    @course_rise360_module_version.destroy!
  end

  # For Publishable
  def course
    @course
  end

  def assignment_name
    @course_rise360_module_version.rise360_module_version.name
  end

  # This launch URL is different from Projects and Surveys, which use 
  # new_*_submission_url(). This is because Rise360Modules are not submitted.
  # The rise360_zipfile automatically emits xAPI events for user interactions
  # with the content that are recorded in Rise360ModuleInteractions, which is
  # then used to automatically grade students for participation/engagement, so
  # we just need a link to the particular version of the module to do an LTI
  # launch.
  # TODO: Convert this to use a static endpoint for LTI launch
  # https://app.asana.com/0/1174274412967132/1199352155608256 
  def lti_launch_url
    rise360_module_version_url(
      @course_rise360_module_version.rise360_module_version,
      protocol: 'https',
    )
  end

  def verify_can_edit!
    @course.verify_can_edit!
  end
end
