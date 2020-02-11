class LessonSubmissionsController < ApplicationController
  include DryCrud::Controllers::Nestable

  nested_resource_of Lesson

  # GET /lesson_submissions
  # GET /lesson_submissions.json
  def index
  end

  # GET /lesson_submissions/1
  # GET /lesson_submissions/1.json
  def show
  end

  private

end
