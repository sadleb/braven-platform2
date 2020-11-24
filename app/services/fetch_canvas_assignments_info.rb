# frozen_string_literal: true
require 'canvas_api'

# Responsible for fetching all assignments for a Canvas course
# and making information about them available. Intended for
# Course Management tools.
class FetchCanvasAssignmentsInfo
  FetchCanvasAssignmentsInfoError = Class.new(StandardError)

  include Rails.application.routes.url_helpers

  attr_reader :canvas_assignment_ids,
              :canvas_waivers_url, :canvas_waivers_assignment_id,
              :canvas_peer_reviews_url, :canvas_peer_reviews_assignment_id,
              :base_course_project_versions, :base_course_survey_versions,
              :base_course_custom_content_versions_mapping # Maps the fetched canvas assignment ID to the bcccv.

  def initialize(canvas_course_id)
    @canvas_course_id = canvas_course_id
    @canvas_assignment_ids = nil
    @canvas_waivers_url  = nil
    @canvas_waivers_assignment_id = nil
    @canvas_peer_reviews_url = nil
    @canvas_peer_reviews_assignment_id = nil
    @base_course_project_versions = nil
    @base_course_survey_versions = nil
    @base_course_custom_content_versions_mapping = nil

    # Add the rest of the assignment types we implement as well. E.g. pre/post
    # accelerator surveys, peer evaluations, attendance, etc
  end

  def run
    canvas_assignments = CanvasAPI.client.get_assignments(@canvas_course_id)

    @canvas_assignment_ids = []
    @base_course_project_versions= []
    @base_course_survey_versions = []
    @base_course_custom_content_versions_mapping = {}

    canvas_assignments.each do |ca|
      @canvas_assignment_ids << ca['id']

      lti_launch_url = parse_lti_launch_url(ca)
      if lti_launch_url
        parse_assignment_info!(lti_launch_url, ca)
      else
        # Not an assignment published with an LTI submission type. We don't care
        # about any of those at the moment but we may in the future.
      end
    end

    self 
  end

private

  def parse_lti_launch_url(canvas_assignment)
    canvas_assignment.dig('external_tool_tag_attributes', 'url')
  end

  def parse_assignment_info!(lti_launch_url, canvas_assignment)
    bcccv = BaseCourseCustomContentVersion.find_by_lti_launch_url(lti_launch_url) 
    add_project_or_survey_info!(bcccv, canvas_assignment) and return if bcccv

    waivers_launch_path = Rails.application.routes.url_helpers.launch_waiver_submissions_path()
    add_waivers_info(canvas_assignment) and return if lti_launch_url =~ /#{waivers_launch_path}/

    base_course = BaseCourse.find_by(canvas_course_id: @canvas_course_id)
    peer_review_submission_path = new_course_peer_review_submission_path(base_course)
    add_peer_review_info(canvas_assignment) and return if lti_launch_url =~ /#{peer_review_submission_path}/
  end

  def add_project_or_survey_info!(base_course_custom_content_version, canvas_assignment)
    if base_course_custom_content_version.is_a?(BaseCourseProjectVersion)
      @base_course_project_versions << base_course_custom_content_version
    elsif base_course_custom_content_version.is_a?(BaseCourseSurveyVersion)
      @base_course_survey_versions << base_course_custom_content_version
    else
      raise FetchCanvasAssignmentsInfoError, "BaseCourseCustomContentVersion type not recognized: #{base_course_custom_content_version.inspect}"
    end

    @base_course_custom_content_versions_mapping[canvas_assignment['id']] = base_course_custom_content_version
  end

  def add_waivers_info(canvas_assignment)
    if @canvas_waivers_url
      raise FetchCanvasAssignmentsInfoError, "Second assignment with Waivers found. First[#{@canvas_waivers_url}]. Second[#{canvas_assignment['html_url']}]"
    else
      @canvas_waivers_url = canvas_assignment['html_url']
      @canvas_waivers_assignment_id = canvas_assignment['id']
    end
  end

  def add_peer_review_info(canvas_assignment)
    if @canvas_peer_reviews_url
      raise FetchCanvasAssignmentsInfoError, "Duplicate Peer Reviews assignment found."\
        "First[#{@canvas_peer_reviews_url}]. "\
        "Second[#{canvas_assignment['html_url']}]."
    end
    @canvas_peer_reviews_url = canvas_assignment['html_url']
    @canvas_peer_reviews_assignment_id = canvas_assignment['id']
  end

end
