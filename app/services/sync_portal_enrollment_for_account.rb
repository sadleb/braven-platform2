# frozen_string_literal: true

# A helper service to perform the logic that takes folks who are confirmed as participants in the
# program in Salesforce and creates their Canvas accounts. Also, moves/drops/completes their
# enrollment when things change.
# TODO: rename to SyncFromSalesforceParticipant
class SyncPortalEnrollmentForAccount

  def initialize(user:, portal_user:, salesforce_participant:, salesforce_program:)
    @portal_user = portal_user
    @sf_participant = salesforce_participant
    @sf_program = salesforce_program
    @user = user
  end

  # Syncs the Canvas enrollments for the given user in the given course, by unenrolling
  # from existing courses, if necessary, and enrolling them in the new course+section.
  #
  # Note: canvas_role = [:StudentEnrollment, :TaEnrollment, :DesignerEnrollment, :TeacherEnrollment]
  def run
    Honeycomb.add_field('salesforce.contact.id', @user.salesforce_id)
    Honeycomb.add_field('salesforce.participant.status', @sf_participant.status)

    logger.info("Started sync enrollment for #{sf_participant.email}")

    sync_contact_info!(user, portal_user, sf_participant)

    case sf_participant.status
    when SalesforceAPI::ENROLLED
      add_enrollment!
    when SalesforceAPI::DROPPED
      drop_enrollment!
    when SalesforceAPI::COMPLETED
      complete_enrollment!
    else
      logger.warn("Doing nothing! Got #{sf.participant.status} from SF")
    end
  end

  private

  attr_reader :portal_user, :sf_participant, :sf_program, :user

  # The logic for who get's sync'd is anyone with a ParticipantStatus == 'Enrolled'. If they have a CohortName
  # set, they are put in a Canvas Section with that name. If it's not set, they are put in a placeholder cohort
  # that corresponds to the day and time that their Learning Lab meets.
  #
  # Assumptions: there are no duplicate Participant objects and if they opt out or drop as a Candidate, the ParticipantStatus is
  # updated accordingly.
  def add_enrollment!
    case sf_participant.role
    when SalesforceAPI::LEADERSHIP_COACH
      sync_enrollment(sf_program.fellow_course_id, RoleConstants::TA_ENROLLMENT,
                      course_section_name)
      sync_enrollment(sf_program.leadership_coach_course_id,
                      RoleConstants::STUDENT_ENROLLMENT,
                      SectionConstants::DEFAULT_SECTION)
    when SalesforceAPI::FELLOW
      sync_enrollment(sf_program.fellow_course_id, RoleConstants::STUDENT_ENROLLMENT,
                      course_section_name)
    when SalesforceAPI::TEACHING_ASSISTANT
      sync_enrollment(sf_program.fellow_course_id, RoleConstants::TA_ENROLLMENT,
                      SectionConstants::TA_SECTION, limit_privileges_to_course_section=false)
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
    case sf_participant.role
    when SalesforceAPI::LEADERSHIP_COACH
      drop_course_enrollment(sf_program.leadership_coach_course_id)
      drop_course_enrollment(sf_program.fellow_course_id)
    when SalesforceAPI::FELLOW
      drop_course_enrollment(sf_program.fellow_course_id)
    when SalesforceAPI::TEACHING_ASSISTANT
      drop_course_enrollment(sf_program.fellow_course_id)
    else
      logger.warn("Got unknown role #{sf_participant.role} from SF")
    end
  end

  def complete_enrollment!
    # NOOP
    # We haven't figured out this yet
  end

  def drop_course_enrollment(canvas_course_id)
    enrollment = find_user_enrollment(canvas_course_id)
    return if enrollment.nil?

    logger.info('Removing user enrollment from canvas')
    canvas_client.delete_enrollment(enrollment: enrollment)
    section = Section.find_by!(canvas_section_id: enrollment.section_id)
    # remove_role passes if the role doesn't exist.
    user.remove_role enrollment.type, section
  end

  # Enroll or update their enrollment in the proper course and section
  def sync_enrollment(canvas_course_id, role, section_name, limit_privileges_to_course_section=true)
    section_name = section_name.blank? ? SectionConstants::DEFAULT_SECTION : section_name
    section = find_or_create_section(canvas_course_id, section_name)

    Honeycomb.add_field('canvas.course.id', canvas_course_id)
    Honeycomb.add_field('canvas.section.name', section.name)
    Honeycomb.add_field('canvas.section.id', section.canvas_section_id)
    Honeycomb.add_field('canvas.section.role', role)

    enrollment = find_user_enrollment(canvas_course_id)
    if enrollment.nil?
      Honeycomb.add_field('sync_portal_enrollment_for_account.new_enrollment', true)
      enroll_user(canvas_course_id, role, section, limit_privileges_to_course_section)
    elsif !enrollment.section_id.eql?(section.canvas_section_id) || !enrollment.type.eql?(role)
      # Section or role has changed.
      # Fetch assignment overrides, so we can replace ones that get deleted in the next step.
      assignment_overrides = canvas_client.get_assignment_overrides_for_course(
        canvas_course_id,
      )

      # Remove the old enrollment and add the new one.
      Honeycomb.add_field('sync_portal_enrollment_for_account.new_enrollment', false)
      drop_course_enrollment(canvas_course_id)
      enroll_user(canvas_course_id, role, section, limit_privileges_to_course_section)

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
      # Field shared with sync_portal_enrollments_for_program, hence the name
      Honeycomb.add_field('sync_portal_enrollment.skip_reason', 'No enrollment changes')
      logger.info("Skipping sync for #{@user.email} as user enrollment looks fine")
    end
  end

  # Pass in a local db section.
  def enroll_user(canvas_course_id, role, section, limit_privileges_to_course_section)
    user.add_role role, section
    canvas_client.enroll_user_in_course(
      portal_user.id, canvas_course_id, role, section.canvas_section_id,
      limit_privileges_to_course_section
    )
  end

  # Creates a local DB Section and a Canvas section, but only returns the local one.
  # Also handles copying Canvas assignment overrides when appropriate.
  def find_or_create_section(canvas_course_id, section_name)
    # This section may be a cohort section or a cohort-schedule section, depending on course_section_name.
    canvas_section = find_canvas_course_section(canvas_course_id, section_name)
    if canvas_section.nil?
      # If the Canvas section didn't already exist, create it now.
      canvas_section = canvas_client.create_lms_section(course_id: canvas_course_id, name: section_name)

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
    end

    # Now that all the Canvas stuff is done, create a local section and return that.
    course = Course.find_by!(canvas_course_id: canvas_course_id)
    Section.find_or_create_by!(
      course_id: course.id,
      name: section_name,
      canvas_section_id: canvas_section.id
    )
  end

  # Sync's information unique to a Salesforce Contact record to Platform and Canvas.
  # This is mainly just the email.
  #
  # Note: We already support changing an email in Salesforce and having that trigger an
  # immediate sync of the contact info, but that could fail. Also, a manual change in
  # Platform or Canvas could make things out of sync.
  def sync_contact_info!(user, canvas_user, salesforce_participant)
    if email_inconsistent?(user.email, canvas_user.email, salesforce_participant.email)
      SyncFromSalesforceContact.new(
        @user,
        SalesforceAPI::SFContact.new(
           salesforce_participant.contact_id,
           salesforce_participant.email,
           salesforce_participant.first_name,
           salesforce_participant.last_name)
      ).run!
    end
  end

  def email_inconsistent?(user_email, canvas_email, salesforce_email)
    Honeycomb.add_field('user.email', user_email)
    Honeycomb.add_field('canvas.user.email', canvas_email)
    Honeycomb.add_field('salesforce.contact.email', salesforce_email)
    emails_inconsistent = (salesforce_email.downcase != user_email.downcase || salesforce_email.downcase != canvas_email.downcase)
    if emails_inconsistent
      Honeycomb.add_field('sync_portal_enrollment_for_account.email_inconsistent', true)
    end
    emails_inconsistent
  end


  # Returns Canvas section.
  def find_canvas_course_section(canvas_course_id, section_name)
    canvas_client.find_section_by(course_id: canvas_course_id, name: section_name)
  end

  def find_user_enrollment(canvas_course_id)
    canvas_client.find_enrollment(user_id: portal_user.id, course_id: canvas_course_id)
  end

  def canvas_client
    CanvasAPI.client
  end

  def logger
    Rails.logger
  end
end
