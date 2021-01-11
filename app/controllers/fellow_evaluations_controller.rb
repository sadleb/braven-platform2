# frozen_string_literal: true

class FellowEvaluationsController < ApplicationController
  include DryCrud::Controllers::Nestable

  # Adds the #publish and #unpublish actions
  include Publishable

  layout 'admin'

  nested_resource_of Course

  def assignment_name
    'TODO: Complete Fellow Evaluations'
  end

  def lti_launch_url
    new_course_fellow_evaluation_submission_url(@course, protocol: 'https')
  end

end
