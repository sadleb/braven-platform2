# frozen_string_literal: true

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

  def initialize(source_course, destination_course_name, section_names=[], time_zone=nil)
    @source_course = source_course
    @destination_course_name = destination_course_name
    @section_names = section_names
    @time_zone = time_zone
  end

  def run
    @destination_course = @source_course.dup
    @destination_course.name = @destination_course_name
    @destination_course.canvas_course_id = nil
    @destination_course.salesforce_program_id = nil
    # By default everything is unlaunched. Only LaunchNewProgram should set this true.
    @destination_course.is_launched = false
    @destination_course.save!

    @canvas_clone_response = start_canvas_course_clone!(@source_course, @destination_course)

    self
  end

  def wait_and_initialize
    after_canvas_launch_completes! do
      InitializeNewCourse.new(@destination_course, @section_names).run
    end
    @destination_course
  end

private

  def start_canvas_course_clone!(source_course, destination_course)
    # Be reasonably sure copy_course is going to work before calling create_course, otherwise
    # you'll end up with a bunch of empty courses in Canvas.
    canvas_course_data = CanvasAPI.client.create_course(destination_course.name, time_zone: @time_zone)
    destination_course.update!(canvas_course_id: canvas_course_data['id'])
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

end
