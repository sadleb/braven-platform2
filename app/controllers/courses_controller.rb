class CoursesController < ApplicationController
  layout 'admin'

  before_action :fetch_canvas_assignment_info, only: [:edit]

  # GET /courses
  def index
    authorize Course
  end

  # GET /courses/1
  def show
    authorize @course
  end

  # GET /courses/new
  def new
    @course = Course.new(new_params)
    authorize @course
  end

  # GET /courses/1/edit
  def edit
    authorize @course
    @course.verify_can_edit!
  end

  # POST /courses
  def create
    @course = Course.new(course_params)
    authorize @course
    respond_to do |format|
      if @course.save
        format.html { redirect_to courses_path, notice: "Course was successfully created." }
        format.json { render :show, status: :created, location: @course }
      else
        format.html { render :new }
        format.json { render json: @course.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /courses/1
  def update
    authorize @course
    respond_to do |format|
      if @course.update(course_params)
        format.html { redirect_to courses_path, notice: "Course was successfully updated." }
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
    @course.verify_can_edit!
    @course.destroy
    respond_to do |format|
      format.html { redirect_to courses_url, notice: "Course was successfully deleted." }
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

    redirect_to courses_path, notice: "Program launch started. Watch out for an email."
  end

  private

  def fetch_canvas_assignment_info
    @canvas_assignment_info = FetchCanvasAssignmentsInfo.new(@course.canvas_course_id).run
  end

  def course_params
    params.require('course').permit(:name, :is_launched, :course_resource_id, :canvas_course_id)
  end

  def new_params
    params.permit()
  end

end
