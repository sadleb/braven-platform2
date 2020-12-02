# frozen_string_literal: true

class PeerReviewsController < ApplicationController
  include DryCrud::Controllers::Nestable

  # Adds the #publish and #unpublish actions
  include Publishable

  layout 'admin'

  nested_resource_of Course

  # Note: the TODO here is the actual name of the assignment. The convention
  # for assignment naming is things like: CLASS: Learning Lab2,
  # MODULE: Lead Authentically, TODO: Submit Peer Reviews
  PEER_REVIEWS_ASSIGNMENT_NAME = 'TODO: Submit Peer Reviews'

  def course
    @course
  end

  def assignment_name
    PEER_REVIEWS_ASSIGNMENT_NAME
  end

  def lti_launch_url
    new_course_peer_review_submission_url(@course, protocol: 'https')
  end

end
