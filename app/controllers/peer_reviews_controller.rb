# frozen_string_literal: true

class PeerReviewsController < ApplicationController
  include DryCrud::Controllers::Nestable

  # Adds the #publish and #unpublish actions
  include Publishable

  layout 'admin'

  nested_resource_of Course

  # Note: make sure this matches the naming conventions we have for the Canvas
  # assignments. For the Capstone project we have:
  #  - GROUP PROJECT: Capstone Challenge
  #  - GROUP PROJECT: Capstone Challenge: Teamwork
  #  - GROUP PROJECT: Complete Peer Evaluations
  PEER_REVIEWS_ASSIGNMENT_NAME = 'GROUP PROJECT: Complete Capstone Evaluations'

  def assignment_name
    PEER_REVIEWS_ASSIGNMENT_NAME
  end

  def lti_launch_url
    new_course_peer_review_submission_url(@course, protocol: 'https')
  end

end
