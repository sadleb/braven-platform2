class CapstoneEvaluationSubmissionsController < ApplicationController
  include DryCrud::Controllers::Nestable
  # Controller actions are defined in Submittable.
  include Submittable
  
  layout 'lti_canvas'

  nested_resource_of Course

  before_action :set_eval_users, only: [:new, :create]
  before_action :set_questions, only: [:new, :create]

private
  def set_eval_users
    @eval_users = []

    # Determine the Accelerator course for this LC Playbook course.
    # Will return `nil` if this is not an LC Playbook course.
    accelerator_canvas_course_id = SalesforceAPI.client.get_accelerator_course_id_from_lc_playbook_course_id(
      @course.canvas_course_id,
    )

    if accelerator_canvas_course_id.present?
      # This is the LC Playbook course.
      @lc_mode = true
      # TODO: Dedup this from fellow_evaluation_submissions_controller!
      accelerator_course = Course.find_by(canvas_course_id: accelerator_canvas_course_id)

      # Get all Accelerator course sections where this user is a TA
      sections_as_ta = current_user
        .sections_with_role(RoleConstants::TA_ENROLLMENT)
        .select { |section| section.course_id == accelerator_course.id }

      # Get all users enrolled as students in each section
      sections_as_ta.each do |section|
        @eval_users += section.students
      end
    else
      # This is the Accelerator (Fellow) course.
      @fellow_mode = true
      # Get the section in this course that the user is enrolled in as a student
      student_section = current_user.student_section_by_course(@course)
      if student_section&.students&.exists?
        # You're enrolled as a student and there are other students in this course
        @eval_users = student_section.students.where.not(id: current_user.id).where.not(canvas_user_id: nil)
      end
    end
  end

  def set_questions
    @questions = CapstoneEvaluationQuestion.all
  end

  # Called by Submittable.create.
  def answers_params_hash
    capstone_evaluation_params = params.require(:capstone_evaluation)
    # Only allow submitting capstone evals for this Fellow's peers, or this LC's Fellows.
    capstone_evaluation_params.permit!.to_h.filter do |user_id|
      @eval_users.any? { |u| u.id.to_s == user_id }
    end
  end
end
