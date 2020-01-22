class CourseContentHistoriesController < ApplicationController
  before_action :set_course_content_history, only: [:show, :edit, :update, :destroy]
  before_action :set_course_content, only: [:index]

  # GET /course_content_histories
  # GET /course_content_histories.json
  def index
    @course_content_histories = @course_content.course_content_history
  end

  # GET /course_content_histories/1
  # GET /course_content_histories/1.json
  def show
  end

  # GET /course_content_histories/new
  def new
    @course_content_history = CourseContentHistory.new
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

    # Use callbacks to share common setup or constraints between actions.
    def set_course_content
      @course_content = CourseContent.find(params[:course_content_id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def course_content_history_params
      params.require(:course_content_history).permit(:course_content_id, :title, :body)
    end
end
