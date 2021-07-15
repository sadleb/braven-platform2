# frozen_string_literal: true

require 'module_grade_calculator'
require 'canvas_api'

class GradeModuleForUserJob < ApplicationJob
  queue_as :default

  # Note a lot of this code is duplicated (but simplified) from app/services/grade_modules.rb.
  def perform(user, canvas_course_id, canvas_assignment_id)

    # TODO: only grade Modules and not things in the LC Playbook b/c it generates
    # email notifications and it's weird.  We probably still want to grade LCs and staff
    # in Modules just so they can test it out though:
    # https://app.asana.com/0/1174274412967132/1199946751486950

    # Explicitly set the user context since this is a background job.
    user.add_to_honeycomb_trace()
    Honeycomb.add_field('canvas.course.id', canvas_course_id.to_s)
    Honeycomb.add_field('canvas.assignment.id', canvas_assignment_id.to_s)

    # Select the max id at the very beginning, so we can use it at the bottom to mark only things
    # before this as old. If we don't do this, we run the risk of marking things as old that we
    # haven't actually processed yet, causing students to get missing or incorrect grades.
    max_id = Rise360ModuleInteraction.maximum(:id)

    unless GradeModules.grading_disabled_for?(canvas_course_id, canvas_assignment_id, user)

      assignment_overrides = CanvasAPI.client.get_assignment_overrides(
        canvas_course_id,
        canvas_assignment_id
      )

      grade = "#{ModuleGradeCalculator.compute_grade(user.id, canvas_assignment_id, assignment_overrides)}%"

      Rails.logger.info("Graded finished Rise360ModuleVersion[user_id = #{user.id}, canvas_course_id = #{canvas_course_id}, " \
        "canvas_assignment_id = #{canvas_assignment_id}] " \
        "- computed grade = #{grade}")

      result = CanvasAPI.client.update_grade(canvas_course_id, canvas_assignment_id, user.canvas_user_id, grade)

      Honeycomb.add_field('grade_module_for_user.sent_to_canvas', true)
      Rails.logger.debug(result)

    end

    Rise360ModuleInteraction.where(
      new: true,
      user: user,
      canvas_course_id: canvas_course_id,
      canvas_assignment_id: canvas_assignment_id,
    ).where('id <= ?', max_id).update_all(new: false)
  end

end
