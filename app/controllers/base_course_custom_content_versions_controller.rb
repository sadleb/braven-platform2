# frozen_string_literal: true

class BaseCourseCustomContentVersionsController < ApplicationController
  include DryCrud::Controllers::Nestable
  include LtiHelper

  layout 'lti_placement'

  nested_resource_of BaseCourse

  before_action :set_custom_content, only: [:create]
  before_action :set_base_course # TODO: shouldn't DryCrud handle this?

  # Show form to select new Project to create as an LTI linked Canvas assignment
  def new
    # If we end up adding a designer role, remember to authorize `ProjectVersion.create?`.
    authorize @base_course_custom_content_version

   # TODO: if this is a Survey, show the survey's list.

    # TODO: exclude those already on this BaseCourse.
    # https://app.asana.com/0/1174274412967132/1198965066699369
    @projects = Project.all
  end

  # Publish a new Project or Survey in Canvas.
  def create
    # If we end up adding a designer role, remember to authorize `ProjectVersion.create?`.
    authorize BaseCourseCustomContentVersion

    # We need to create the Canvas assignment to get the ID in order to setup the join table
    # here in platform
    ca = CanvasAPI.client.create_lti_assignment(@base_course.canvas_course_id, @custom_content.title)
   
    # Setup the join table and then update the Canvas assignment to launch it
    custom_content_version = @custom_content.save_version!(current_user)
    @course_content_version = BaseCourseCustomContentVersion.create!(
      base_course: @base_course,
      custom_content_version: custom_content_version,
      canvas_assignment_id: ca['id']
    )
  
  # TODO: polymorphic path for Project vs Survey
  
    # Create a submission URL for this course and content version

    submission_url = new_base_course_custom_content_version_project_submission_url(
      base_course_custom_content_version_id: @course_content_version.id,
    )
  
    CanvasAPI.client.update_assignment_lti_launch_url(@base_course.canvas_course_id, ca['id'], submission_url)
    
    respond_to do |format|
      format.html { redirect_to edit_polymorphic_path(@base_course), notice: "'#{@custom_content.title}' successfully published to Canvas." }
      format.json { head :no_content }
    end
  rescue => e
    @course_content_version.destroy if @course_content_version
    CanvasAPI.client.delete_assignment(@base_course.canvas_course_id, ca['id']) if @base_course.canvas_course_id && ca['id']
    raise
  end

  # Publish the latest Project, Survey, etc (aka CustomContent) so that the Canvas assignment this
  # BaseCourseCustomContentVersion represents shows the latest content.
  def update
    authorize @base_course_custom_content_version

    custom_content = @base_course_custom_content_version.custom_content_version.custom_content
    new_custom_content_version = custom_content.save_version!(current_user)
    @base_course_custom_content_version.custom_content_version = new_custom_content_version
    @base_course_custom_content_version.save!

    respond_to do |format|
      format.html { redirect_to edit_polymorphic_path(@base_course), notice: "Latest version of '#{custom_content.title}' successfully published to Canvas." }
      format.json { head :no_content }
    end
  end

  # Deletes a Project, Survey, etc (aka CustomContent) from the Canvas course that this
  # BaseCourseCustomContentVersion join model represents and then deletes this record locally.
  def destroy
    authorize @base_course_custom_content_version
    name = @base_course_custom_content_version.custom_content_version.title

    # TODO: make this transactional in nature: https://app.asana.com/0/1174274412967132/1198984932600565
    CanvasAPI.client.delete_assignment(@base_course.canvas_course_id, @base_course_custom_content_version.canvas_assignment_id)
    @base_course_custom_content_version.destroy

    respond_to do |format|
      format.html { redirect_to edit_polymorphic_path(@base_course), notice: "'#{name}' was successfully deleted from '#{@base_course.name}' in Canvas." }
      format.json { head :no_content }
    end
  end

  private
  def set_custom_content
    params.require(:custom_content_id)
    @custom_content = CustomContent.find(params[:custom_content_id])
  end

  def set_base_course
    @base_course = BaseCourse.find(params.require(:base_course_id))
    @base_course.verify_can_edit!
  end

end
