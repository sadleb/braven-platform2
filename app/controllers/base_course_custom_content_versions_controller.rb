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

    BaseCourseCustomContentVersion.publish!(
      @base_course,
      @custom_content,
      @current_user,
      params[:rubric_id],
    )

    respond_to do |format|
      format.html { redirect_to edit_polymorphic_path(@base_course), notice: "'#{@custom_content.title}' successfully published to Canvas." }
      format.json { head :no_content }
    end

  end

  # Publish the latest Project, Survey, etc (aka CustomContent) so that the Canvas assignment this
  # BaseCourseCustomContentVersion represents shows the latest content.
  def update
    authorize @base_course_custom_content_version

    @base_course_custom_content_version.publish_latest!(@current_user)

    respond_to do |format|
      format.html { redirect_to edit_polymorphic_path(@base_course), notice: "Latest version of '#{@custom_content.title}' successfully published to Canvas." }
      format.json { head :no_content }
    end
  end

  # Deletes a Project, Survey, etc (aka CustomContent) from the Canvas course that this
  # BaseCourseCustomContentVersion join model represents and then deletes this record locally.
  def destroy
    authorize @base_course_custom_content_version
    title = @base_course_custom_content_version.custom_content_version.title

    @base_course_custom_content_version.remove!

    respond_to do |format|
      format.html { redirect_to edit_polymorphic_path(@base_course), notice: "'#{title}' was successfully deleted from '#{@base_course.name}' in Canvas." }
      format.json { head :no_content }
    end
  end

  def humanized_custom_content_type 
    custom_content_class.model_name.human
  end
  helper_method :humanized_custom_content_type

  def for_project?
    custom_content_class == Project
  end
  helper_method :for_project?

private

  def custom_content_class
    case params[:type]
    when nil
      BaseCourseCustomContent
    when 'BaseCourseProjectVersion'
      Project
    when 'BaseCourseSurveyVersion'
      Survey
    else
      raise TypeError.new "Unknown BaseCourseCustomContentVersion type: #{params[:type]}"
    end
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
