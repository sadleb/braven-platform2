# frozen_string_literal: true
require 'salesforce_api'
require 'canvas_api'
require 'zoom_api'

# Sync's a Salesforce Participant to Platform and Canvas.
# TODO: rename to SyncParticipant or SyncSalesforceParticipant
class SyncPortalEnrollmentForAccount

  def initialize(salesforce_participant, salesforce_program, force_zoom_update)
    @sf_participant = salesforce_participant
    @sf_contact = SalesforceAPI.participant_struct_to_contact_struct(salesforce_participant)
    @sf_program = salesforce_program
    @force_zoom_update = force_zoom_update
  end

  # Handles all syncing logic for a Participant, such as:
  # 1. creating them when they become Enrolled
  # 2. syncing their email and other Contact info
  # 3. moving them between sections if their enrollment changes
  # 4. unenrolling them if they become Dropped
  # 5. adding them to the proper TA Caseload section
  # 6. syncing their Zoom links
  #
  # Note: canvas_role = [:StudentEnrollment, :TaEnrollment, :DesignerEnrollment, :TeacherEnrollment]
  def run
    # Note that putting the span inside the begin/rescue and letting exceptions bubble through
    # the block causes Honeycomb to automatically set the 'error' and 'error_detail' fields.
    Honeycomb.start_span(name: 'sync_portal_enrollment_for_account.run') do
      sf_participant.add_to_honeycomb_span()
      Honeycomb.add_field('sync_portal_enrollment_for_account.complete?', false)

      # Find or create local users and make sure they are in sync with Salesforce (and Canvas)
      create_new_user = (sf_participant.status == SalesforceAPI::ENROLLED)
      sync_contact_service = SyncFromSalesforceContact.new(@sf_contact, create_new_user)
      @user = sync_contact_service.run

      # Note that we run this before the enrollment stuff b/c we want to have the Zoom
      # links in Salesforce even if we end up short-circuting out below b/c they haven't
      # created their Canvas account yet (by registering).
      sync_zoom_links()

      logger.info("Started sync enrollment for #{sf_participant.email}")

      case sf_participant.status
      when SalesforceAPI::ENROLLED
        add_enrollment!
      when SalesforceAPI::DROPPED
        drop_enrollment!
      when SalesforceAPI::COMPLETED
        complete_enrollment!
      else
        logger.warn("Doing nothing! Got #{sf_participant.status} from SF")
      end
      Honeycomb.add_field('sync_portal_enrollment_for_account.complete?', true)
    end
  end

  private

  attr_reader :sf_participant, :sf_program, :user

  # The logic for who get's sync'd is anyone with a ParticipantStatus == 'Enrolled'. If they have a CohortName
  # set, they are put in a Canvas Section with that name. If it's not set, they are put in a placeholder cohort
  # that corresponds to the day and time that their Learning Lab meets.
  #
  # Assumptions: there are no duplicate Participant objects and if they opt out or drop as a Candidate, the ParticipantStatus is
  # updated accordingly.
  def add_enrollment!
    case sf_participant.role
    when SalesforceAPI::LEADERSHIP_COACH
      sync_primary_enrollment(sf_program.fellow_course_id, RoleConstants::TA_ENROLLMENT,
                      course_section_name)
      sync_primary_enrollment(sf_program.leadership_coach_course_id,
                      RoleConstants::STUDENT_ENROLLMENT,
                      SectionConstants::DEFAULT_SECTION)

    when SalesforceAPI::FELLOW
      sync_primary_enrollment(sf_program.fellow_course_id, RoleConstants::STUDENT_ENROLLMENT,
                      course_section_name)
      SyncTaCaseloadForParticipant.new(@user, sf_participant, sf_program).run if @user.has_canvas_account?

    when SalesforceAPI::TEACHING_ASSISTANT
      sync_primary_enrollment(sf_program.fellow_course_id, RoleConstants::TA_ENROLLMENT,
                        SectionConstants::TA_SECTION, limit_privileges_to_course_section=false)
      sync_primary_enrollment(sf_program.leadership_coach_course_id, RoleConstants::TA_ENROLLMENT,
                        SectionConstants::TA_SECTION, limit_privileges_to_course_section=false)
      SyncTaCaseloadForParticipant.new(@user, sf_participant, sf_program).run if @user.has_canvas_account?
      give_ta_permissions()
    else
      logger.warn("Got unknown role #{sf_participant.role} from SF")
    end
  end

  # If the CohortName isn't set, get their LL day/time schedule and use a placeholder section
  # that we setup before they are mapped to their real cohort in the 2nd or 3rd week.
  # This function controlls a lot of the behavior in this service!
  def course_section_name
    sf_participant.cohort || # E.g. SJSU Brian (Tues)
      sf_participant.cohort_schedule # E.g. 'Monday, 7:00'
  end

  def drop_enrollment!
    if @user.blank?
      Honeycomb.add_field('sync_portal_enrollment_for_account.skip_reason', 'Dropped Participant never synced before')
      return
    end

    case sf_participant.role
    when SalesforceAPI::LEADERSHIP_COACH
      drop_course_enrollments(sf_program.leadership_coach_course_id)
      drop_course_enrollments(sf_program.fellow_course_id)
    when SalesforceAPI::FELLOW
      drop_course_enrollments(sf_program.fellow_course_id)
    when SalesforceAPI::TEACHING_ASSISTANT
      drop_course_enrollments(sf_program.fellow_course_id)
      drop_course_enrollments(sf_program.leadership_coach_course_id)
      remove_ta_permissions()
    else
      logger.warn("Got unknown role #{sf_participant.role} from SF")
    end
  end

  def complete_enrollment!
    # NOOP
    # We haven't figured out this yet
  end

  def drop_course_enrollments(canvas_course_id)
    if @user.has_canvas_account?
      enrollments = canvas_client.find_enrollments_for_course_and_user(canvas_course_id, user.canvas_user_id)
      Honeycomb.add_field('canvas.enrollments.count', enrollments&.count)

      logger.info('Removing user enrollments from canvas')
      enrollments&.each { |enrollment|
        canvas_client.delete_enrollment(enrollment: enrollment)
      }
    end

    # Even if they had no Canvas account, they may have local Section roles
    # which we still need to remove since we give them local roles as soon as they
    # become an Enrolled Participant in Salesforce.
    course = Course.find_by!(canvas_course_id: canvas_course_id)
    user.remove_section_roles(course)
  end

  # Enroll or update their primary enrollment in the proper course and section
  # The primary enrollment controls the due dates and corresponds to either their
  # Cohort or Cohort Schedule in Salesforce (or some default section if neither applies).
  def sync_primary_enrollment(canvas_course_id, role, section_name, limit_privileges_to_course_section=true)
    Honeycomb.start_span(name: 'sync_portal_enrollment_for_account.sync_primary_enrollment') do
      Honeycomb.add_field('canvas.course.id', canvas_course_id.to_s)
      Honeycomb.add_field('canvas.section.role', role)

      course = Course.find_by!(canvas_course_id: canvas_course_id)
      Honeycomb.add_field('course.id', course.id)

      existing_sections = user.sections_by_course(course)
      existing_section = existing_sections.first
      existing_role_name = user.roles_by_section(existing_section).first&.name&.to_sym if existing_section
      Honeycomb.add_field('canvas.section.name.existing', existing_section&.name)
      Honeycomb.add_field('canvas.section.id.existing', existing_section&.canvas_section_id.to_s)
      Honeycomb.add_field('canvas.section.role.existing', existing_role_name)

      # Idealy, we'd raise an exception here. Starting with an alert and if we see that
      # this more or less can't happen with the current code, let's switch this to raise.
      # Either way, below we remove roles for all sections for this course below before
      # getting the proper one in place.
      if existing_sections && existing_sections.count > 1
        Honeycomb.add_field('alert.duplicate_sections_for_user', true)
      end

      # Even before someone has registered and created their Canvas account, we create the Canvas
      # section they would get enrolled in and ensure that they are in the local Section for it
      # so that features which rely on the local Section roles work from day 1. E.g. attendance
      section_name = section_name.blank? ? SectionConstants::DEFAULT_SECTION : section_name
      new_section = find_or_create_section(course, section_name)
      Honeycomb.add_field('canvas.section.name', new_section.name)
      Honeycomb.add_field('canvas.section.id', new_section.canvas_section_id.to_s)

      unless @user.has_canvas_account?
        # Adjust the user's local Section roles even if they don't have a Canvas account
        user.remove_section_roles(course)
        user.add_role role, new_section

        Honeycomb.add_field('sync_portal_enrollment_for_account.skip_reason', 'No Canvas account yet')
        logger.info("Skipping sync primary enrollment for #{user.email}. No Canvas account.")
        return
      end

      # Check to see if we need to adjust their enrollment in Canvas. Note that we have to actually
      # call into Canvas to check the enrollment b/c the local sections may be setup properly before
      # they create their Canvas account.
      enrollment = canvas_client.find_enrollment(
        canvas_user_id: user.canvas_user_id,
        canvas_section_id: new_section.canvas_section_id
      )

      if existing_section.nil? || enrollment.nil?
        # Brand new first time enrollment
        Honeycomb.add_field('sync_portal_enrollment_for_account.new_enrollment', true)
        enroll_user(canvas_course_id, role, new_section, limit_privileges_to_course_section)

      elsif !existing_section.canvas_section_id.eql?(new_section.canvas_section_id) || !existing_role_name&.eql?(role)
        # Section or role has changed.
        # Fetch assignment overrides, so we can replace ones that get deleted in the next step.
        assignment_overrides = canvas_client.get_assignment_overrides_for_course(
          canvas_course_id,
        )

        # Remove the old enrollment and add the new one.
        Honeycomb.add_field('sync_portal_enrollment_for_account.new_enrollment', false)
        drop_course_enrollments(canvas_course_id)
        enroll_user(canvas_course_id, role, new_section, limit_privileges_to_course_section)

        # Add back overrides for this user.
        new_overrides = []
        assignment_overrides.each do |override|
          if override.has_key? 'student_ids' and override['student_ids'].include? user.canvas_user_id
            override.delete('id')
            new_overrides << override
          end
        end

        Honeycomb.add_field('sync_portal_enrollment_for_account.new_overrides.count', new_overrides.count)
        if new_overrides.count > 0
          logger.info("Copying assignment overrides: #{new_overrides}")
          canvas_client.create_assignment_overrides(canvas_course_id, new_overrides)
        end
      else
        Honeycomb.add_field('sync_portal_enrollment_for_account.skip_reason', 'No enrollment changes')
        logger.info("Skipping sync enrollment for #{@user.email}. No enrollment changes.")
      end
    end
  end

  # A TA_ENROLLMENT gives them permission to take attendance on behalf of an LC as
  # well as masquerade as other users. We use TA accounts for staff as well as real
  # Teaching Assistants in an "admin" capacity of sorts.
  def give_ta_permissions()
    @user.add_role RoleConstants::CAN_TAKE_ATTENDANCE_FOR_ALL
    if @user.has_canvas_account?
      canvas_client.assign_account_role(@user.canvas_user_id, CanvasConstants::STAFF_ACCOUNT_ROLE_ID)
    end
  end

  def remove_ta_permissions()
    @user.remove_role RoleConstants::CAN_TAKE_ATTENDANCE_FOR_ALL
    if @user.has_canvas_account?
      canvas_client.unassign_account_role(@user.canvas_user_id, CanvasConstants::STAFF_ACCOUNT_ROLE_ID)
    end
  rescue RestClient::NotFound
    # This gets thrown if the account role was manually deleted or never assigned. Fine to skip.
    Honeycomb.add_field('sync_portal_enrollment_for_account.staff_account_role.not_found', true)
  end

  # Pass in a local db section.
  def enroll_user(canvas_course_id, role, section, limit_privileges_to_course_section)
    user.add_role role, section
    canvas_client.enroll_user_in_course(
      user.canvas_user_id, canvas_course_id, role, section.canvas_section_id,
      limit_privileges_to_course_section
    )
  end

  # Finds or creates a local DB Section and a Canvas section, but only returns the local one.
  # Also handles copying Canvas assignment overrides when appropriate.
  def find_or_create_section(course, section_name)
    canvas_course_id = course.canvas_course_id
    existing_section = Section.find_by(
      course_id: course.id,
      name: section_name,
    )
    return existing_section if existing_section.present?

    # If the Canvas section didn't already exist, create it now.
    canvas_section = canvas_client.create_lms_section(course_id: canvas_course_id, name: section_name)

    # The above section may be a cohort section or a cohort-schedule section, depending on course_section_name.
    if sf_participant.cohort
      # The user has been added to a cohort without an existing section.
      # Copy the due dates from the cohort-schedule section to the new section.
      # Note: This also means canvas_section is guaranteed to be a cohort section.
      cohort_schedule_section = find_canvas_course_section(canvas_course_id, sf_participant.cohort_schedule)
      # In the edge case where the cohort-schedule section doesn't already
      # exist in Canvas, we just skip all this assignment-override stuff.
      if cohort_schedule_section
        cohort_schedule_overrides = []
        # Unfortunately, the only way to get a list of overrides from Canvas is to
        # check each assignment in the course. One API call per assignment.
        assignment_ids = canvas_client.get_assignments(canvas_course_id).map { |a| a['id'] }
        assignment_ids.each do |assignment_id|
          overrides = canvas_client.get_assignment_overrides(canvas_course_id, assignment_id)
          # Exit early if there aren't any overrides for this assignment.
          next unless overrides

          # For assignment overrides in the cohort-schedule section, update the override
          # config to point to the new section, remove the override ID, and add the
          # override to a big list of all overrides to copy to the new section.
          overrides.each do |override|
            if override['course_section_id'] == cohort_schedule_section.id
              override['course_section_id'] = canvas_section.id
              override.delete('id')
              cohort_schedule_overrides << override
            end
          end
        end
        # Copy all the overrides at once, to reduce the number of API calls.
        canvas_client.create_assignment_overrides(canvas_course_id, cohort_schedule_overrides)
      end
    end

    # Now that all the Canvas stuff is done, create a local section and return that.
    Section.create!(
      course_id: course.id,
      name: section_name,
      canvas_section_id: canvas_section.id
    )
  end # find_or_create_section

  # Returns Canvas section.
  def find_canvas_course_section(canvas_course_id, section_name)
    canvas_client.find_section_by(course_id: canvas_course_id, name: section_name)
  end

  def sync_zoom_links
    SyncZoomLinksForParticipant.new(sf_participant, @force_zoom_update).run
  rescue  ZoomAPI::TooManyRequestsError => e
    # This happens if you try to hit the API for a given email / meeting pair more than
    # 3 times in a day. Just skip and wait until tomorrow and it should work.
    Sentry.capture_exception(e)
    Honeycomb.add_field('zoom.participant.skip_reason', e.message)
    Rails.logger.debug(e.message)
  end

  def canvas_client
    CanvasAPI.client
  end

  def logger
    Rails.logger
  end
end
