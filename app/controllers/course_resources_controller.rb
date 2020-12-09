class CourseResourcesController < ApplicationController

  # Add the #new and #create actions
  include Attachable

  include LtiHelper

  layout 'admin'

  before_action :set_lti_launch, only: [:lti_show]

  def lti_show
    authorize CourseResource
    canvas_course_id = @lti_launch.request_message.custom['course_id']
    course = Course.find_by(canvas_course_id: canvas_course_id)
    if course&.course_resource
      url = Addressable::URI.parse(course.course_resource.launch_url)
      url.query_values = helpers.launch_query
      redirect_to url.to_s
    else
      render plain: "Course resources not configured!", status: 404
    end
  end

end
