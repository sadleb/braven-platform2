
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
    # Get all sections where this user is a TA
    sections_as_ta = current_user.sections_with_role(RoleConstants::TA_ENROLLMENT)

    # TODO: https://app.asana.com/0/1174274412967132/1199547040938233
    # Determine the Accelerator course for this LC Playbook course using
    # Salesforce so we don't show fellows from previous runs

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
