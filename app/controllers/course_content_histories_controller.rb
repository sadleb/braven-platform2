class CourseContentHistoriesController < ApplicationController
  before_action :set_course_content_history, only: [:show, :edit, :update, :destroy]

  # GET /course_content_histories
  # GET /course_content_histories.json
  def index
    @course_content_histories = CourseContentHistory.all
  end

  # GET /course_content_histories/1
  # GET /course_content_histories/1.json
  def show
  end

  # GET /course_content_histories/new
  def new
    @course_content_history = CourseContentHistory.new
  end

  # GET /course_content_histories/1/edit
  def edit
  end

  # POST /course_content_histories
  # POST /course_content_histories.json
  def create
    @course_content_history = CourseContentHistory.new(course_content_history_params)

    respond_to do |format|
      if @course_content_history.save
        format.html { redirect_to @course_content_history, notice: 'Course content history was successfully created.' }
        format.json { render :show, status: :created, location: @course_content_history }
      else
        format.html { render :new }
        format.json { render json: @course_content_history.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /course_content_histories/1
  # PATCH/PUT /course_content_histories/1.json
  def update
    respond_to do |format|
      if @course_content_history.update(course_content_history_params)
        format.html { redirect_to @course_content_history, notice: 'Course content history was successfully updated.' }
        format.json { render :show, status: :ok, location: @course_content_history }
      else
        format.html { render :edit }
        format.json { render json: @course_content_history.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /course_content_histories/1
  # DELETE /course_content_histories/1.json
  def destroy
    @course_content_history.destroy
    respond_to do |format|
      format.html { redirect_to course_content_histories_url, notice: 'Course content history was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_course_content_history
      @course_content_history = CourseContentHistory.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def course_content_history_params
      params.require(:course_content_history).permit(:course_content_id, :title, :body)
    end
end
