# frozen_string_literal: true

class PeerReviewsController < ApplicationController
  include DryCrud::Controllers::Nestable

  # Adds the #publish and #unpublish actions
  include Publishable

  layout 'admin'

  nested_resource_of BaseCourse

  def base_course
    @base_course
  end

  def assignment_name
    @assignment_name = 'Peer Reviews'
  end

  def lti_launch_url
    new_course_peer_review_submission_url(@base_course)
  end

end
