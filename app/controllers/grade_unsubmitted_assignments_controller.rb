# frozen_string_literal: true

class GradeUnsubmittedAssignmentsController < ApplicationController
  include DryCrud::Controllers::Nestable
  nested_resource_of Course

  def grade
    authorize :GradeUnsubmittedAssignments
    service = GradeUnsubmittedAssignments.new([@course.canvas_course_id], false)
    service.run
    redirect_to @course, notice: 'Graded unsubmitted assignments.'
  end
end
