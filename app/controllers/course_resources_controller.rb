class CourseResourcesController < ApplicationController

  # Add the #new and #create actions
  include Attachable

  include LtiHelper

  layout 'admin'

  before_action :set_lti_launch, only: [:lti_show]

  def lti_show
    authorize CourseResource
    canvas_course_id = @lti_launch.request_message.canvas_course_id
    course = Course.find_by(canvas_course_id: canvas_course_id)
    if course&.course_resource
      url = Addressable::URI.parse(course.course_resource.launch_url)
      url.query_values = helpers.launch_query
      course_resources_url = url.to_s
      redirect_to course_resources_url
    else
      render plain: "Course resources not configured!", status: 404
    end
  end

private
  # For attachable
  def redirect_path
    courses_path
  end
end
