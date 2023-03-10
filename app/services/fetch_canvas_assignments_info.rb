# frozen_string_literal: true
require 'canvas_api'

# Responsible for fetching all assignments for a Canvas course
# and making information about them available. Intended for
# Course Management tools.
class FetchCanvasAssignmentsInfo
  FetchCanvasAssignmentsInfoError = Class.new(StandardError)

  include Rails.application.routes.url_helpers

  attr_reader :canvas_assignment_ids,
              :canvas_forms_url, :canvas_forms_assignment_id,
              :canvas_preaccelerator_survey_url, :canvas_preaccelerator_survey_assignment_id,
              :canvas_postaccelerator_survey_url, :canvas_postaccelerator_survey_assignment_id,
              :canvas_capstone_evaluations_url, :canvas_capstone_evaluations_assignment_id,
              :canvas_capstone_evaluation_results_url, :canvas_capstone_evaluation_results_assignment_id,
              :canvas_discord_signups_url, :canvas_discord_signups_assignment_id,
              :course_project_versions, :course_survey_versions,
              :course_custom_content_versions_mapping,  # Maps the fetched canvas assignment ID to the cccv.
              :course_attendance_events_mapping,
              :rise360_module_versions_mapping

  def initialize(canvas_course_id)
    @canvas_course_id = canvas_course_id
    @canvas_assignment_ids = nil

    @canvas_forms_url  = nil
    @canvas_forms_assignment_id = nil

    @canvas_preaccelerator_survey_url = nil
    @canvas_preaccelerator_survey_assignment_id  = nil

    @canvas_postaccelerator_survey_url = nil
    @canvas_postaccelerator_survey_assignment_id  = nil

    @canvas_capstone_evaluations_url = nil
    @canvas_capstone_evaluations_assignment_id = nil

    @canvas_capstone_evaluation_results_url = nil
    @canvas_capstone_evaluation_results_assignment_id = nil

    @canvas_discord_signups_url = nil
    @canvas_discord_signups_assignment_id = nil

    @course_project_versions = nil
    @course_survey_versions = nil
    @course_custom_content_versions_mapping = nil

    @course_attendance_events_mapping = nil

    @rise360_module_versions_mapping = nil

    # Add the rest of the assignment types we implement as well. E.g. pre/post
    # accelerator surveys, capstone evaluations, attendance, etc
  end

  def run
    Honeycomb.start_span(name: 'fetch_canvas_assignments_info.run') do
      Honeycomb.add_field('canvas.course.id', @canvas_course_id.to_s)

      canvas_assignments = CanvasAPI.client.get_assignments(@canvas_course_id)

      @canvas_assignment_ids = []
      @course_project_versions= []
      @course_survey_versions = []
      @course_custom_content_versions_mapping = {}
      @course_attendance_events_mapping = {}
      @rise360_module_versions_mapping = {}

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
    end

    self
  end

private

  def parse_lti_launch_url(canvas_assignment)
    canvas_assignment.dig('external_tool_tag_attributes', 'url')
  end

  def parse_assignment_info!(lti_launch_url, canvas_assignment)
    Honeycomb.start_span(name: 'fetch_canvas_assignments_info.parse_assignment_info!') do
      Honeycomb.add_field('canvas.course.id', @canvas_course_id.to_s)
      Honeycomb.add_field('canvas.assignment.id', canvas_assignment['id'].to_s)
      Honeycomb.add_field('canvas.assignment.name', canvas_assignment['name'])
      Honeycomb.add_field('canvas.assignment.launch_url', lti_launch_url)

      cccv = CourseCustomContentVersion.find_by_lti_launch_url(lti_launch_url)
      add_project_or_survey_info!(cccv, canvas_assignment) and return if cccv

      rise360_module_version = Rise360ModuleVersion.find_by_lti_launch_url(lti_launch_url)
      add_module_info(rise360_module_version, canvas_assignment) and return if rise360_module_version

      # Doesn't matter which Course the CourseAttendanceEvent is attached to, because we'll be
      # replacing the course. Just get one with the right AttendanceEvent.
      attendance_event_submission_answer_path = launch_attendance_event_submission_answers_path
      if lti_launch_url =~ /#{attendance_event_submission_answer_path}/
        attendance_event = AttendanceEvent.find_by(title: canvas_assignment['name'])
        course_attendance_event = CourseAttendanceEvent.find_by(attendance_event_id: attendance_event&.id)
        if course_attendance_event.present?
          add_attendance_event_info(course_attendance_event, canvas_assignment)
        else
          msg = "No local Platform attedance event found for the Canvas '#{canvas_assignment['name']}' " +
                "assignment in Canvas Course ID: #{@canvas_course_id}"
          Honeycomb.add_alert('missing_course_attendance_event', msg)
        end
        return
      end

      # We don't use new_**course**_capstone_evaluation_submission_path here because
      # InitializeNewCourse needs to be able to detect the LTI launch URL that
      # was copied containing the old course ID
      capstone_evaluation_submission_path = 'capstone_evaluation_submissions/new'
      add_capstone_evaluation_info(canvas_assignment) and return if lti_launch_url =~ /#{capstone_evaluation_submission_path}/

      capstone_evaluation_result_path = launch_capstone_evaluation_results_path
      add_capstone_evaluation_result_info(canvas_assignment) and return if lti_launch_url =~ /#{capstone_evaluation_result_path}/

      forms_launch_path = launch_form_submissions_path
      add_forms_info(canvas_assignment) and return if lti_launch_url =~ /#{forms_launch_path}/

      discord_signups_launch_path = launch_discord_signups_path
      add_discord_signups_info(canvas_assignment) and return if lti_launch_url =~ /#{discord_signups_launch_path}/

      preaccelerator_survey_submission_path = launch_preaccelerator_survey_submissions_path
      add_preaccelerator_survey_info(canvas_assignment) and return if lti_launch_url =~ /#{preaccelerator_survey_submission_path}/

      postaccelerator_survey_submission_path = launch_postaccelerator_survey_submissions_path
      add_postaccelerator_survey_info(canvas_assignment) and return if lti_launch_url =~ /#{postaccelerator_survey_submission_path}/
    end
  end

  def add_project_or_survey_info!(course_custom_content_version, canvas_assignment)
    if course_custom_content_version.is_a?(CourseProjectVersion)
      @course_project_versions << course_custom_content_version
    elsif course_custom_content_version.is_a?(CourseSurveyVersion)
      @course_survey_versions << course_custom_content_version
    else
      raise FetchCanvasAssignmentsInfoError, "CourseCustomContentVersion type not recognized: #{course_custom_content_version.inspect}"
    end

    @course_custom_content_versions_mapping[canvas_assignment['id']] = course_custom_content_version
  end

  def add_module_info(rise360_module_version, canvas_assignment)
    @rise360_module_versions_mapping[canvas_assignment['id']] = rise360_module_version
  end

  def add_attendance_event_info(course_attendance_event, canvas_assignment)
    @course_attendance_events_mapping[canvas_assignment['id']] = course_attendance_event
  end

  def add_forms_info(canvas_assignment)
    if @canvas_forms_url
      raise FetchCanvasAssignmentsInfoError, "Second assignment with Forms found. First[#{@canvas_forms_url}]. Second[#{canvas_assignment['html_url']}]"
    else
      @canvas_forms_url = canvas_assignment['html_url']
      @canvas_forms_assignment_id = canvas_assignment['id']
    end
  end

  def add_discord_signups_info(canvas_assignment)
    if @canvas_discord_signups_url
      raise FetchCanvasAssignmentsInfoError, "Second assignment with Discord Signups found. First[#{@canvas_discord_signups_url}]. Second[#{canvas_assignment['html_url']}]"
    else
      @canvas_discord_signups_url = canvas_assignment['html_url']
      @canvas_discord_signups_assignment_id = canvas_assignment['id']
    end
  end

  def add_capstone_evaluation_info(canvas_assignment)
    if @canvas_capstone_evaluations_url
      raise FetchCanvasAssignmentsInfoError, "Duplicate Capstone Evaluations assignment found."\
        "First[#{@canvas_capstone_evaluations_url}]. "\
        "Second[#{canvas_assignment['html_url']}]."
    end
    @canvas_capstone_evaluations_url = canvas_assignment['html_url']
    @canvas_capstone_evaluations_assignment_id = canvas_assignment['id']
  end

  def add_capstone_evaluation_result_info(canvas_assignment)
    if @canvas_capstone_evaluation_results_url
      raise FetchCanvasAssignmentsInfoError, "Duplicate Capstone Evaluation Results assignment found."\
        "First[#{@canvas_capstone_evaluation_results_url}]. "\
        "Second[#{canvas_assignment['html_url']}]."
    end
    @canvas_capstone_evaluation_results_url = canvas_assignment['html_url']
    @canvas_capstone_evaluation_results_assignment_id = canvas_assignment['id']
  end

  def add_preaccelerator_survey_info(canvas_assignment)
    if @canvas_preaccelerator_survey_url
      raise FetchCanvasAssignmentsInfoError, "Duplicate Pre-Accelerator Survey assignment found."\
        "First[#{@canvas_preaccelerator_survey_url}]. "\
        "Second[#{canvas_assignment['html_url']}]."
    end
    @canvas_preaccelerator_survey_url = canvas_assignment['html_url']
    @canvas_preaccelerator_survey_assignment_id = canvas_assignment['id']
  end

  def add_postaccelerator_survey_info(canvas_assignment)
    if @canvas_postaccelerator_survey_url
      raise FetchCanvasAssignmentsInfoError, "Duplicate Post-Accelerator Survey assignment found."\
        "First[#{@canvas_postaccelerator_survey_url}]. "\
        "Second[#{canvas_assignment['html_url']}]."
    end
    @canvas_postaccelerator_survey_url = canvas_assignment['html_url']
    @canvas_postaccelerator_survey_assignment_id = canvas_assignment['id']
  end
end
