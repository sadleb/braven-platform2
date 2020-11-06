# frozen_string_literal: true

class BaseCourseCustomContentVersionsController < ApplicationController
  include LtiHelper

  layout 'admin'

  before_action :set_base_course
  before_action :set_custom_content, except: [:new]
  before_action :set_new_custom_contents, only: [:new]
  before_action :set_rubrics, only: [:new], if: :for_project?
  before_action :verify_can_edit!

  # Show form to select new Project or Survey to create as an LTI linked Canvas assignment
  def new
    # If we end up adding a designer role, remember to authorize `ProjectVersion.create?`.
    authorize @base_course_custom_content_version
  end

  # Publish a new Project or Survey in Canvas.
  def create
    # If we end up adding a designer role, remember to authorize `ProjectVersion.create?`.
    authorize BaseCourseCustomContentVersion

    # We need to create the Canvas assignment to get the ID in order to setup the join table
    # here in platform
    ca = CanvasAPI.client.create_lti_assignment(@base_course.canvas_course_id, @custom_content.title)
    canvas_assignment_id = ca['id']
   
    # Setup the join table and then update the Canvas assignment to launch it
    @base_course_custom_content_version = BaseCourseCustomContentVersion.create!(
      base_course: @base_course,
      custom_content_version: @custom_content.save_version!(current_user),
      canvas_assignment_id: canvas_assignment_id,
    )

    # Create a submission URL for this course and content version
    submission_url = @base_course_custom_content_version.new_submission_url
  
    CanvasAPI.client.update_assignment_lti_launch_url(@base_course.canvas_course_id, canvas_assignment_id, submission_url)

    if params[:rubric_id].present?
      CanvasAPI.client.add_rubric_to_assignment(@base_course.canvas_course_id, canvas_assignment_id, params[:rubric_id])
    end
   
    respond_to do |format|
      format.html { redirect_to edit_polymorphic_path(@base_course), notice: "'#{@custom_content.title}' successfully published to Canvas." }
      format.json { head :no_content }
    end
  rescue => e
    @base_course_custom_content_version.destroy if @base_course_custom_content_version
    CanvasAPI.client.delete_assignment(@base_course.canvas_course_id, canvas_assignment_id) if @base_course.canvas_course_id && canvas_assignment_id
    raise
  end

  # Publish the latest Project, Survey, etc (aka CustomContent) so that the Canvas assignment this
  # BaseCourseCustomContentVersion represents shows the latest content.
  def update
    authorize @base_course_custom_content_version

    @base_course_custom_content_version.update!(
      custom_content_version: @custom_content.save_version!(current_user),
    )

    respond_to do |format|
      format.html { redirect_to edit_polymorphic_path(@base_course), notice: "Latest version of '#{@custom_content.title}' successfully published to Canvas." }
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

  def for_project?
    custom_content_class == Project
  end
  helper_method :for_project?

private
  def custom_content_class
    CustomContentsController.class_from_type(params[:type])
  end

  def set_base_course
    @base_course = params[:base_course_id] ?
      BaseCourse.find(params[:base_course_id]) :
      @base_course_custom_content_version.base_course
  end

  def set_custom_content
    @custom_content = params[:custom_content_id] ?
      CustomContent.find(params[:custom_content_id]) :
      @base_course_custom_content_version.custom_content_version.custom_content
  end

  def set_new_custom_contents
    @new_custom_contents = custom_content_class.all - @base_course.custom_contents
  end

  def set_rubrics
    @rubrics = CanvasAPI.client.get_rubrics(
      @base_course.canvas_course_id,
      true, # filter_already_associated_rubrics
    )
  end

  def verify_can_edit!
    @base_course.verify_can_edit!
  end
end
