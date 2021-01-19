# frozen_string_literal: true

class LaunchProgram
  LaunchProgramError = Class.new(StandardError)

  def initialize(salesforce_program_id, fellow_source_course_id, fellow_course_name, lc_source_course_id, lc_course_name)

    set_salesforce_vars(salesforce_program_id)

    @fellow_source_course = Course.find(fellow_source_course_id)
    @fellow_course_name = fellow_course_name
    @lc_source_course = Course.find(lc_source_course_id)
    @lc_course_name = lc_course_name
  end

  def run
    # Kick off both canvas clones before we start waiting on them.
    fellow_clone_service = CloneCourse.new(@fellow_source_course, @fellow_course_name, @fellow_destination_course_section_names, @salesforce_program.timezone.to_s).run
    lc_clone_service = CloneCourse.new(@lc_source_course, @lc_course_name, @lc_destination_course_section_names, @salesforce_program.timezone.to_s).run

    # Wait till they are cloned and initialized before updating Salesforce
    @fellow_destination_course = fellow_clone_service.wait_and_initialize
    @lc_destination_course = lc_clone_service.wait_and_initialize
 
    # Update Salesforce program with the new Canvas course IDs.
    sf_client.set_canvas_course_ids(
      @salesforce_program.id,
      @fellow_destination_course.canvas_course_id,
      @lc_destination_course.canvas_course_id
    )

    # We're all set and everything worked. Mark the courses as launched.
    @fellow_destination_course.update!(is_launched: true)
    @lc_destination_course.update!(is_launched: true)
  end

private

  def set_salesforce_vars(salesforce_program_id)
    # TODO: Ideally, we would validate the Program info, like that there are Cohort Schedules and the "Coach Course Section Name" field is set,
    # at the time we're launching it instead of as part of the background job (where this is run). That way we can give immediate feedback if they're trying
    # to launch a program that has not been setup properly with the info we need to be able to launch it. This makes me wonder if we
    # should be introducing back a local platform Program model that represents the mapping of all the program related stuff. E.g.
    # we could use it to map LC to Accelerator courses. We could store the Cohort and Cohort Schedule names and use them to do the sync
    # logic when there are new ones or changes. We could store the state of the program, whether it's active or not, so that we can filter out
    # access to old content for returning LCs or Fellows who drop but come back for a future run. E.g current LCs shouldn't see attendance for
    # for attendance assignments for previous semesters event though they are in those sections.
    #
    # If we did that, then we could create the Program active record before launching the job which does this validation in the main UI
    # and then pass it to the job using a GlobalID parameter: https://edgeguides.rubyonrails.org/active_job_basics.html#globalid
    # Task to track: https://app.asana.com/0/1174274412967132/1198877695027085

    @salesforce_program = sf_client.find_program(id: salesforce_program_id)

    @lc_destination_course_section_names = [ SectionConstants::DEFAULT_SECTION ]
    @fellow_destination_course_section_names = sf_client.get_cohort_schedule_section_names(salesforce_program_id)

    if @fellow_destination_course_section_names.blank?
      raise LaunchProgramError, 'No Cohort Schedules found for this Salesforce Program. Make sure those are setup first.'
    end
  end

  def sf_client
    SalesforceAPI.client
  end

end
