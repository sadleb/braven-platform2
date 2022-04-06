require 'salesforce_api'

# This controller handles Leadership Coaches (LCs) submitting a review for the
# Fellows in their section.
# In this controller, we assume the current_user is an LC and the course is the
# LC Playbook course where the LC is enrolled as a student in Canvas.
class FellowEvaluationSubmissionsController < ApplicationController
  include DryCrud::Controllers::Nestable
  # Controller actions are defined in Submittable.
  include Submittable

  layout 'lti_canvas'

  # Note: We assume the Course is an LC Playbook (not Accelerator) course
  nested_resource_of Course

  before_action :set_fellow_users, only: [:new, :create]

private
  def set_fellow_users
    # TODO: Dedup this from capstone_evaluation_submissions_controller.rb!

    # Determine the Accelerator course for this LC Playbook course
    accelerator_canvas_course_id = SalesforceAPI.client.get_accelerator_course_id_from_lc_playbook_course_id(
      @course.canvas_course_id,
    )
    accelerator_course = Course.find_by(canvas_course_id: accelerator_canvas_course_id)

    # Get all Accelerator course sections where this user is a TA
    sections_as_ta = current_user.ta_sections.where(course: accelerator_course)

    # Get all users enrolled as students in each section
    @fellow_users = []
    sections_as_ta.each do |section|
      @fellow_users += section.students
    end
  end

  # Called by Submittable.create.
  def answers_params_hash
    fellow_evaluation_params = params.require(:fellow_evaluation)
    # Only allow submitting evaluation for fellows.
    fellow_evaluation_params.permit!.to_h.filter do |user_id|
      @fellow_users.any? { |user| user.id.to_s == user_id.to_s }
    end
  end
end
