class CourseContentAnswersController < ApplicationController
  before_action :set_course_content_answer, only: [:show, :update, :destroy]
  before_action :set_course_content, only: [:index]

  # GET /course_content_answers
  # GET /course_content_answers.json
  def index
    @course_content_answers = @course_content.course_content_answer
  end

  # GET /course_content_answers/1
  # GET /course_content_answers/1.json
  def show
  end

  # POST /course_content_answers
  # POST /course_content_answers.json
  def create
    @course_content_answer = CourseContentAnswer.new(course_content_answer_params)

    if @course_content_answer.save
      render :show, status: :created, location: @course_content_answer
    else
      render json: @course_content_answer.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /course_content_answers/1
  # PATCH/PUT /course_content_answers/1.json
  def update
    if @course_content_answer.update(course_content_answer_params)
      render :show, status: :ok, location: @course_content_answer
    else
      render json: @course_content_answer.errors, status: :unprocessable_entity
    end
  end

  # DELETE /course_content_answers/1
  # DELETE /course_content_answers/1.json
  def destroy
    @course_content_answer.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_course_content_answer
      @course_content_answer = CourseContentAnswer.find(params[:id])
    end

    def set_course_content
      @course_content = CourseContent.find(params[:course_content_id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def course_content_answer_params
      params.require(:course_content_answer).permit(:uuid, :course_content_id, :correctness, :mastery, :instant_feedback)
    end
end
