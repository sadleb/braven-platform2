# frozen_string_literal: true

class Rise360ModuleGradesController < ApplicationController
  include LtiHelper

  before_action :set_lti_launch, only: [:show]

  layout 'lti_canvas'

  def show
    authorize @rise360_module_grade
    @all_interactions_for_lti_launch_context = policy_scope(@rise360_module_grade)
    @new_ungraded_interactions = @all_interactions_for_lti_launch_context.select { |i|
      i.new == true
    }
  end

  #def create
  #  # These are created from a Rise360 package emitting xApi calls to our
  #  # LrsXapiMock server. Go look in lib/lrs_xapi_mock.rb
  #end

private

  def grade_is_up_to_date?
    @new_ungraded_interactions.blank?
  end
  helper_method :grade_is_up_to_date?

  def canvas_url
    @rise360_module_grade.course_rise360_module_version.canvas_url
  end
  helper_method :canvas_url
 end
