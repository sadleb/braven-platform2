# frozen_string_literal: true

require 'canvas_api'

class GradeRise360ModuleForUserJob < ApplicationJob
  queue_as :default

  def perform(user, lti_launch)

    # Explicitly set the user and launch context since this is a background job.
    user.add_to_honeycomb_trace()
    lti_launch.add_to_honeycomb_trace()

    crmv = CourseRise360ModuleVersion.find_by(canvas_assignment_id: lti_launch.assignment_id)

    grading_service = GradeRise360ModuleForUser.new(user, crmv)
    grading_service.run

  end

end
