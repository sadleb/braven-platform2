class CourseContent < ApplicationRecord
  has_many :course_content_history
  has_many :course_content_undo

  def publish(params)
    response = CanvasProdClient.update_course_page(params[:course_id], params[:secondary_id], params[:body])

    response.code >= 200 && response.code < 300
  end
end
