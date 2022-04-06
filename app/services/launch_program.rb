# frozen_string_literal: true
require 'canvas_api'

class LaunchProgram
  LaunchProgramError = Class.new(StandardError)

  attr_reader :fellow_destination_course, :lc_destination_course

  def initialize(salesforce_program_id, fellow_source_course_id, fellow_course_name, lc_source_course_id, lc_course_name)
    @salesforce_program_id = salesforce_program_id
    set_salesforce_program()

    @fellow_source_course = Course.find(fellow_source_course_id)
    @fellow_course_name = fellow_course_name
    @lc_source_course = Course.find(lc_source_course_id)
    @lc_course_name = lc_course_name
  end

  def run
    Honeycomb.start_span(name: 'launch_program.run') do

      term = CanvasAPI.client.create_enrollment_term(@salesforce_program.term_name, @salesforce_program.sis_term_id)
      Honeycomb.add_field('canvas.term.id', term['id'])
      Honeycomb.add_field('canvas.term.sis_id', @salesforce_program.sis_term_id)
      Honeycomb.add_field('canvas.term.name', @salesforce_program.term_name)

      # Kick off both canvas clones before we start waiting on them.
      fellow_clone_service = CloneCourse.new(@fellow_source_course, @fellow_course_name, @salesforce_program).run
      lc_clone_service = CloneCourse.new(@lc_source_course, @lc_course_name, @salesforce_program).run

      @fellow_destination_course = fellow_clone_service.wait_and_initialize
      @lc_destination_course = lc_clone_service.wait_and_initialize

      # We're all set and everything worked. Mark the courses as launched!
      @fellow_destination_course.update!(is_launched: true)
      @lc_destination_course.update!(is_launched: true)
    end
  end

private

  def set_salesforce_program
    # TODO: Ideally, we would validate the Program info, like that there are Cohort Schedules and the "Coach Course Section Name" field is set,
    # at the time we're launching it instead of as part of the background job (where this is run). That way we can give immediate feedback if they're trying
    # to launch a program that has not been setup properly with the info we need to be able to launch it. This makes me wonder if we
    # should be introducing back a local platform Program model that represents the mapping of all the program related stuff.
    # (UPDATE: the below does use a local HerokuConnect model now. Leaving this comment here b/c it's about early validation before launching the job)
    # E.g.  # we could use it to map LC to Accelerator courses. We could store the Cohort and Cohort Schedule names and use them to do the sync
    # logic when there are new ones or changes. We could store the state of the program, whether it's active or not, so that we can filter out
    # access to old content for returning LCs or Fellows who drop but come back for a future run. E.g current LCs shouldn't see attendance for
    # for attendance assignments for previous semesters event though they are in those sections.
    #
    # If we did that, then we could create the Program active record before launching the job which does this validation in the main UI
    # and then pass it to the job using a GlobalID parameter: https://edgeguides.rubyonrails.org/active_job_basics.html#globalid
    # Task to track: https://app.asana.com/0/1174274412967132/1198877695027085

    @salesforce_program = HerokuConnect::Program.find(@salesforce_program_id)

    if @salesforce_program.cohort_schedules.blank?
      raise LaunchProgramError, 'No Cohort Schedules found for this Salesforce Program. Make sure to set those up first.'
    end
  end

end
