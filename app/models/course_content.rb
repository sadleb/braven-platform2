require 'canvas_api'

class CourseContent < ApplicationRecord
  has_many :course_content_histories
  has_one_attached :course_content_zipfile

  def publish(params)
    response = CanvasAPI.client.update_course_page(params[:course_id], params[:secondary_id], params[:body])

    # Some APIs return 200, some 201.
    response.code == 200 or response.code == 201
  end
end
