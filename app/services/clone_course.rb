# frozen_string_literal: true
require 'canvas_api'
require 'salesforce_api'

# Clones a Canvas course and the associated platform Course info.
# It takes a minute, so calling `run` kicks it off while
# `wait_and_initialize` does just that -- it blocks until the
# copy is complete in Canvas and then initializes it so that the
# local platform data is in sync (aka LTI launched assignments are
# linked to the correct thing).
#
# Note: this clone's the Canvas course, but under the covers it actually
# uses the Canvas Content Migrations API since the clone API is deprecated:
# https://canvas.instructure.com/doc/api/content_migrations.html
class CloneCourse
  CloneCourseError = Class.new(StandardError)

  def initialize(source_course, destination_course_name, salesforce_program)
    @source_course = source_course
    @destination_course_name = destination_course_name
    @salesforce_program = salesforce_program
  end

  def run
    Honeycomb.start_span(name: 'clone_course.run') do
      add_to_honeycomb_span()

      @destination_course = @source_course.dup
      @destination_course.name = @destination_course_name
      @destination_course.salesforce_program_id = @salesforce_program.sfid
      @destination_course.canvas_course_id = nil
      @destination_course.last_canvas_sis_import_id = nil
      # By default everything is unlaunched. Only LaunchNewProgram should set this true.
      @destination_course.is_launched = false
      @destination_course.save!
      add_to_honeycomb_span()

      @canvas_clone_response = start_canvas_course_clone!(@source_course, @destination_course)
    end

    self
  end

  def wait_and_initialize
    Honeycomb.start_span(name: 'clone_course.wait_and_initialize') do
      add_to_honeycomb_span()

      after_canvas_launch_completes! do
        InitializeNewCourse.new(@destination_course, @salesforce_program).run
        update_salesforce()
      end
    end

    @destination_course
  end

private

  def start_canvas_course_clone!(source_course, destination_course)
    # Be reasonably sure copy_course is going to work before calling create_course, otherwise
    # you'll end up with a bunch of empty courses in Canvas.
    canvas_course_data = CanvasAPI.client.create_course(
      destination_course.name,
      destination_course.sis_id,
      @salesforce_program.sis_term_id,
      @salesforce_program.time_zone
    )
    canvas_course_id = canvas_course_data['id']
    Honeycomb.add_field('clone_course.destination_canvas_course_id', canvas_course_id)
    destination_course.update!(canvas_course_id: canvas_course_id)
    CanvasAPI.client.copy_course(source_course.canvas_course_id, destination_course.canvas_course_id)
  end

  def after_canvas_launch_completes!(&block)
    progress_url = @canvas_clone_response['progress_url']
    start_time = Time.now
    while (@canvas_clone_response['workflow_state'] != 'completed' && @canvas_clone_response['workflow_state'] != 'failed')

      if @canvas_clone_response['workflow_state'] == 'failed'
        raise CloneCourseError, "Canvas course copy failed. See: #{@canvas_clone_response['migration_issues_url']}"
      end

      if (Time.now - start_time) > 3.minutes # Fail safe so this doesn't poll forever.
        raise CloneCourseError, 'Canvas course copy timed out after 3 minutes'
      end

      sleep 5.seconds

      @canvas_clone_response = CanvasAPI.client.get_copy_course_status(progress_url)
    end
    block.call
  end

  def update_salesforce
    salesforce_field_name = nil
    if @source_course.is_accelerator_course?
      salesforce_field_name = 'Canvas_Cloud_Accelerator_Course_ID__c'
    elsif @source_course.is_lc_playbook_course?
      salesforce_field_name = 'Canvas_Cloud_LC_Playbook_Course_ID__c'
    end

    unless salesforce_field_name.nil?
      SalesforceAPI.client.update_program(
        @salesforce_program.sfid,
        { salesforce_field_name => @destination_course.canvas_course_id }
      )
    else
      Honeycomb.add_alert('unknown_course_type',
        "Cant determine if #{@source_course.name} is an Accelerator course or " +
        "a LC Playbook course. Failed to update Salesforce. To fix, go to Program ID: " +
        "'#{@salesforce_program.sfid}' and manually set the proper " +
        "'Course ID - Highlander' field to #{@destination_course.canvas_course_id}"
      )
      @source_course.add_to_honeycomb_span('.source')
      @destination_course.add_to_honeycomb_span('.destination')
    end
  end

  def add_to_honeycomb_span
    Honeycomb.add_field('clone_course.destination_course_name', @destination_course_name)
    @salesforce_program.add_to_honeycomb_trace()
    @source_course.add_to_honeycomb_span('.source')
    @destination_course&.add_to_honeycomb_span('.destination')
  end

end
