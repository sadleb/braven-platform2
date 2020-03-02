class CourseContent < ApplicationRecord
  has_many :course_content_history
  has_many :course_content_undo

  def publish(params)
    response = CanvasProdClient.update_course_page(params[:course_id], params[:secondary_id], params[:body])

    # Some APIs return 200, some 201.
    response.code == :ok or response.code == :created
  end
end
