# frozen_string_literal: true

class CoursesController < ApplicationController
  layout 'admin'
  CourseAdminError = Class.new(StandardError)

  before_action :fetch_canvas_assignment_info, only: [:edit]

  # GET /courses
  def index
    authorize Course
    current_canvas_course_ids = SalesforceAPI.client.get_current_and_future_canvas_course_ids()
    @current_launched_courses = @courses.launched_courses.where(canvas_course_id: current_canvas_course_ids)
    @past_launched_courses = @courses.launched_courses.where.not(canvas_course_id: current_canvas_course_ids)
  end

  # GET /courses/1
  def show
    authorize @course
  end

  # Used to create and initialize a new Course Template
  # (aka a Course that is not launched). New launched courses
  # can only be created using the Launch New Program service.
  #
  # GET /courses/new
  def new
    authorize Course
    params.require(:create_from_course_id)
  end

  # GET /courses/1/edit
  def edit
    authorize @course
  end

  # Creates a new Course Template from an existing Course (launched or not).
  # Course Templates are those that have `is_launched` set to false. Use
  # Launch New Program to turn a Course Template into a launched Course.
  # POST /courses
  def create
    authorize Course
    params.require(:create_from_course_id)

    @source_course = Course.find(params[:create_from_course_id])

    CloneCourseJob.perform_later(current_user.email, @source_course, create_params[:name])

    redirect_to courses_path, notice: 'Course Template initialization started. Watch out for an email.'
  end

  # PATCH/PUT /courses/1
  def update
    authorize @course
    respond_to do |format|
      if @course.update(update_params)
        format.html { redirect_to courses_path, notice: 'Course was successfully updated.' }
        format.json { render :show, status: :ok, location: @course }
      else
        format.html { redirect_to edit_course_path(@course) }
        format.json { render json: @course.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /courses/1
  def destroy
    authorize @course
    raise CourseAdminError.new 'Cannot delete a launched course' if @course.is_launched
    @course.destroy
    respond_to do |format|
      format.html { redirect_to courses_url, notice: 'Course was successfully deleted.' }
      format.json { head :no_content }
    end
  end

  # Nonstandard actions related to course management.

  # GET /courses/launch
  def launch_new
    authorize Course
    @unlaunched_courses = Course.unlaunched_courses
  end

  # POST /courses/launch
  def launch_create
    authorize Course

    # Validate form.
    begin
      salesforce_program_id, notification_email, fellow_source_course_id, fellow_course_name, lc_source_course_id, lc_course_name = params.require([
        :salesforce_program_id,
        :notification_email,
        :fellow_source_course_id,
        :fellow_course_name,
        :lc_source_course_id,
        :lc_course_name
      ])
      raise ActionController::BadRequest.new("Can't use the same source course for Fellow and LC course") if fellow_source_course_id == lc_source_course_id
    rescue ActionController::ParameterMissing, ActionController::BadRequest => e
      redirect_to launch_courses_path, alert: "Error: #{e.message}" and return
    end

    # Start the program launch job
    LaunchProgramJob.perform_later(salesforce_program_id, notification_email, fellow_source_course_id, fellow_course_name, lc_source_course_id, lc_course_name)

    redirect_to courses_path, notice: 'Program launch started. Watch out for an email.'
  end

  private

  def fetch_canvas_assignment_info
    @canvas_assignment_info = FetchCanvasAssignmentsInfo.new(@course.canvas_course_id).run
  end

  def update_params
    params.require('course').permit(:name, :is_launched, :course_resource_id, :canvas_course_id)
  end

  def create_params
    params.require('course').permit(:name)
  end

end
