class LessonSubmissionsController < ApplicationController
  before_action :set_lesson_submission, only: [:show]

  # GET /lesson_submissions
  # GET /lesson_submissions.json
  def index
    @lesson_submissions = params[:lesson_id] ? LessonSubmission.where(lesson_id: params[:lesson_id]) : LessonSubmission.all
  end

  # GET /lesson_submissions/1
  # GET /lesson_submissions/1.json
  def show
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_lesson_submission
    @lesson_submission = LessonSubmission.find(params[:id])
  end
end
