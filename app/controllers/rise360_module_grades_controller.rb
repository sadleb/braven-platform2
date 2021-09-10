# frozen_string_literal: true

class Rise360ModuleGradesController < ApplicationController
  include LtiHelper

  before_action :set_lti_launch, only: [:show]

  layout 'lti_canvas'

  def show
    authorize @rise360_module_grade
    @grading_service = GradeRise360ModuleForUser.new(
      @rise360_module_grade.user,
      @rise360_module_grade.course_rise360_module_version,
      true
    )
    @grading_service.run
    @computed_grade_breakdown = @grading_service.computed_grade_breakdown
  end

  #def create
  #  # These are created on the fly if they don't exist and we need them for grading logic.
  #  # grep for Rise360ModuleGrade.create_or_find_by to see where
  #  # (for example in rise360_module_versions_controller#ensure_submission)
  #end

private

  def canvas_url
    @rise360_module_grade.course_rise360_module_version.canvas_url
  end
  helper_method :canvas_url
 end
