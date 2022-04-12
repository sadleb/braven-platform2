# frozen_string_literal: true
require 'canvas_api'
require 'salesforce_api'

# Syncs a Participant across Salesforce, Platform, and Canvas by:
# - creating new local and Canvas platform Users
# - creating new local and Canvas Sections
# - adding the necessary user, section, enrollment, and admin rows to the
#   SisImportDataSet to give them appropriate Canvas access. See there for more info.
# - syncing the local User Roles to match
#
# IMPORTANT: if a row is omitted from the .csvs, that means they will lose that
# access if they had it before.
#
# Assumptions: when a new Program is launched:
# - the SIS ID of the course is set properly
# - a Canvas "term" is created for the Program and set on the Accelerator and LC Playbook courses
# - the Teaching Assistants and Cohort Schedule sections are created in both courses
#
# See here for more info: https://github.com/bebraven/platform/wiki/Salesforce-Sync
class SyncSalesforceParticipant

  def initialize(sis_import_data_set, salesforce_program, participant_sync_info)
    @sis_import_data_set = sis_import_data_set
    @salesforce_program = salesforce_program
    @participant_sync_info = participant_sync_info
  end

  def run
    Honeycomb.start_span(name: 'sync_salesforce_participant.run') do
      @accelerator_course = @salesforce_program.accelerator_course
      @lc_playbook_course = @salesforce_program.lc_playbook_course
      @participant_sync_info.add_to_honeycomb_span()

      set_user()
      set_accelerator_course_enrollments()
      set_lc_playbook_course_enrollments()
      set_canvas_ta_caseload_enrollments()
      set_admin_permissions()
    end
  end

private

  def set_user
    return unless @participant_sync_info.is_enrolled?
    user = sync_user()
    @sis_import_data_set.add_user(user)
  end

  # Folks are enrolled in all the sections that apply to them in Canvas, but only one locally.
  # Before CohortTheThis is either in the Cohort Schedule section or the Cohort section depending
  # on whether Cohort mapping has happened yet (aka Fellows are assigned their
  # Leadership Coaches and put together in a Cohort with them).
  #
  # When a new Program is launched Cohort Schedules sections are created both locally and
  # in Canvas. These are where the due dates are set in Canvas (manually).
  #
  # When Cohort mapping happens (aka Fellows are assigned their Leadership Coaches and put
  # together in a Cohort with them), sections are created for the Cohorts both locally and
  # in Canvas on the fly. In Canvas, folks are in both their Cohort Schedule and their Cohort
  # section. The former is to control the due dates, the later is for everything else.
  # Locally in Platform, they are only in one section though. That will be their Cohort section
  # after mapping happens. This controls their Pundit policy access as well as other features
  # that operation on a Cohort, like attendance or Capstone Challenge Evaluations.
  def set_accelerator_course_enrollments
    cohort_schedule_section = nil
    cohort_section = nil
    ta_section = nil

    if @participant_sync_info.is_enrolled?
      case @participant_sync_info.role_category
      when SalesforceConstants::RoleCategory::FELLOW, SalesforceConstants::RoleCategory::LEADERSHIP_COACH

        cohort_schedule_section = set_canvas_section_enrollment(
          @accelerator_course, Section::Type::COHORT_SCHEDULE, @participant_sync_info.accelerator_course_role
        )

        cohort_section = set_canvas_section_enrollment(
          @accelerator_course, Section::Type::COHORT, @participant_sync_info.accelerator_course_role
        ) if @participant_sync_info.cohort_id.present?

      when SalesforceConstants::RoleCategory::TEACHING_ASSISTANT

        ta_section = set_canvas_section_enrollment(
          @accelerator_course, Section::Type::TEACHING_ASSISTANTS, RoleConstants::TA_ENROLLMENT, false
        )

      else
        raise RuntimeError, "Unrecognized Participant role_category '#{@participant_sync_info.role_category}' for Participant ID: #{@participant_sync_info.sfid}"
      end
    end

    sync_local_accelerator_enrollment(cohort_schedule_section, cohort_section, ta_section)
  end

  def set_lc_playbook_course_enrollments
    return unless @participant_sync_info.is_enrolled?

    lc_playbook_course_role = @participant_sync_info.lc_playbook_course_role
    return if lc_playbook_course_role.nil?

    local_section = nil
    case @participant_sync_info.role_category
    when SalesforceConstants::RoleCategory::LEADERSHIP_COACH
      local_section = set_canvas_section_enrollment(
        @lc_playbook_course, Section::Type::COHORT_SCHEDULE, lc_playbook_course_role
      )

    when SalesforceConstants::RoleCategory::TEACHING_ASSISTANT
      local_section = set_canvas_section_enrollment(
        @lc_playbook_course, Section::Type::TEACHING_ASSISTANTS, lc_playbook_course_role, false
      )
    end

    sync_local_lc_playbook_enrollment(local_section)
  end

  def set_canvas_section_enrollment(course, section_type, enrollment_role, limit_section_privileges=true)
    section = set_canvas_section(course, section_type)
    @sis_import_data_set.add_enrollment(@participant_sync_info.user, section, enrollment_role, limit_section_privileges)
    section
  end

  def set_canvas_section(course, section_type)
    section = nil

    case section_type
    when Section::Type::COHORT
      section = find_or_create_cohort_section()
      sync_local_section_name(section, @participant_sync_info.cohort_section_name)

    when Section::Type::COHORT_SCHEDULE
      # This should only happen if it was once set and get's unset. We don't start syncing
      # folks until they have a Cohort Schedule.
      if @participant_sync_info.cohort_schedule_id.blank?
        raise SyncSalesforceProgram::NoCohortScheduleError.new(
          "No Cohort Schedule assigned to Participant ID: #{@participant_sync_info.sfid}. " +
          "Make sure and set one."
        )
      end

      section = Section.find_by(salesforce_id: @participant_sync_info.cohort_schedule_id, course: course)
      raise SyncSalesforceProgram::MissingSectionError.new(
        "The Cohort Schedule '#{@participant_sync_info.cohort_schedule_section_name}' (ID: #{@participant_sync_info.cohort_schedule_id}) " +
        "is missing a local Platform Section for Course: #{course.inspect}. " +
        "This was supposed to be created as part of Program launch."
      ) if section.nil?

      sync_local_section_name(section, @participant_sync_info.cohort_schedule_section_name)

    when Section::Type::TEACHING_ASSISTANTS
      # Each course should have one and only one 'Teaching Assistants' section setup as part of Program launch.
      section = Section.find_by(course: course, section_type: Section::Type::TEACHING_ASSISTANTS)
      raise SyncSalesforceProgram::MissingSectionError.new(
        "The '#{SectionConstants::TA_SECTION}' section is missing a local Platform Section for Course: #{course.inspect}. " +
        "This was supposed to be created as part of Program launch."
      ) if section.nil?

    else
      raise SyncSalesforceProgram::SectionSetupError, "section_type '#{section_type}' not implemented"
    end

    @sis_import_data_set.add_section(section)

    section

  # Errors with setting the Canvas section can effect more than just this Particpant
  # Convert these to a SectionSetupError so that the sync knows to stop the overall sync
  # instead of skipping this Participant.
  rescue => e
    raise if e.is_a?(SyncSalesforceProgram::SectionSetupError)
    raise if e.is_a?(SyncSalesforceProgram::NoCohortScheduleError) # These are Participant specific

    Sentry.capture_exception(e)
    raise SyncSalesforceProgram::SectionSetupError.new(
      "Could not process section_type=#{section_type} for canvas_course_id=#{course.canvas_course_id}." +
      "Check Sentry for more deatils."
    )
  end

  # Makes sure an Enrolled Fellow or Teaching Assistant is in the proper "TA Caseload(name)" Canvas
  # section(s). These sections allow TAs to filter the gradebook down to only the Fellows
  # they are responsible for grading.
  def set_canvas_ta_caseload_enrollments
    return unless @participant_sync_info.is_enrolled?
    return if @participant_sync_info.ta_caseload_enrollments.blank?

    @participant_sync_info.ta_caseload_enrollments.each do |enrollment|
      section = find_or_create_ta_caseload_section(enrollment)
      @sis_import_data_set.add_section(section)
      @sis_import_data_set.add_enrollment(@participant_sync_info.user, section, @participant_sync_info.ta_caseload_role, true)
    end
  end

  # A TA_ENROLLMENT gives them permission to take attendance on behalf of an LC as
  # well as masquerade as other users. We use TA accounts for staff as well as real
  # Teaching Assistants in an "admin" capacity of sorts.
  def set_admin_permissions
    if @participant_sync_info.has_canvas_staff_permissions?
      if @participant_sync_info.is_enrolled?
        @participant_sync_info.user.add_role RoleConstants::CAN_TAKE_ATTENDANCE_FOR_ALL
        @sis_import_data_set.add_staff_account_role(@participant_sync_info.user)
      else
        @participant_sync_info.user.remove_role RoleConstants::CAN_TAKE_ATTENDANCE_FOR_ALL
      end
    end
  end

  def find_or_create_ta_caseload_section(ta_caseload_enrollment)
    section_name = HerokuConnect::Participant.ta_caseload_section_name_for(ta_caseload_enrollment['ta_name'])
    find_or_create_section(
      @accelerator_course,
      section_name,
      ta_caseload_enrollment['ta_participant_id'],
      Section::Type::TA_CASELOAD
    )
  end

  def find_or_create_cohort_section()
    find_or_create_section(
      @accelerator_course,
      @participant_sync_info.cohort_section_name,
      @participant_sync_info.cohort_id,
      Section::Type::COHORT
    )
  end

  def find_or_create_section(course, section_name, salesforce_id, section_type)
    # There is a unique DB constraint on [salesforce_id, course_id] so this
    # is sufficient to look up existing ones since we only use this for Cohort
    # and TA Caseload sections which have a salesforce_id.
    section = Section.find_by(salesforce_id: salesforce_id, course: course)
    return section unless section.nil?

    # If we get here, this is the first person being added to a Cohort. Set it up locally and in Canvas.
    CreateSection.new(course, section_name, section_type, salesforce_id).run
  rescue => e
    Sentry.capture_exception(e)
    raise SyncSalesforceProgram::CreateSectionError.new(
      "Failed to create a Section for: " +
      "canvas_course_id=#{course.canvas_course_id}, section_name='#{section_name}', section_type=#{section_type}. " +
      "See Sentry for more details."
    )
  end

  def sync_local_section_name(local_section, salesforce_section_name)
    return if local_section.name == salesforce_section_name
    local_section.update!(name: salesforce_section_name)
  end

  def sync_user
    if @participant_sync_info.contact_changed?
      synced_user = SyncSalesforceContact.new(
        @participant_sync_info.contact_id,
        @salesforce_program.time_zone
      ).run

      @participant_sync_info.user = synced_user
      @participant_sync_info.user_id = synced_user.id
      @participant_sync_info.canvas_user_id = synced_user.canvas_user_id
    end

    @participant_sync_info.user
  end


  # Participants should only have one local Section / Role per course.
  # This is what controls their Pundit policy permissions as well as what drives
  # some features that require us to operate on all folks in a given Section
  # like Attendance for example.
  def sync_local_accelerator_enrollment(cohort_schedule_section, cohort_section, ta_section)
    return unless @participant_sync_info.accelerator_enrollment_changed?

    # Now that we know something changed about their primary enrollment, just drop everything and
    # add back what they are supposed to have. This is much simpler than comparing what
    # they currently have to what they should have and making the necessary changes.
    @participant_sync_info.user.remove_section_roles(@accelerator_course)

    return if @participant_sync_info.is_dropped?

    if @participant_sync_info.role_category == SalesforceConstants::RoleCategory::TEACHING_ASSISTANT
      raise ArgumentError, "ta_section is nil" if ta_section.nil?
      @participant_sync_info.user.add_role @participant_sync_info.accelerator_course_role, ta_section
      return
    end

    # Fellows and Leadership Coaches go in their Cohort Schedule section if they haven't
    # been mapped to a Cohort yet. Otherwise, they go in the Cohort section.
    if @participant_sync_info.is_mapped_to_cohort?
      @participant_sync_info.user.add_role @participant_sync_info.accelerator_course_role, cohort_section
    else
      @participant_sync_info.user.add_role @participant_sync_info.accelerator_course_role, cohort_schedule_section
    end
  end

  # TAs and LCs should only have one local Section / Role per course.
  # This is what controls their Pundit policy permissions as well as what drives
  # some features that require us to operate on all folks in a given Section
  # like Attendance for example.
  def sync_local_lc_playbook_enrollment(local_section)
    return unless @participant_sync_info.lc_playbook_enrollment_changed?

    @participant_sync_info.user.remove_section_roles(@lc_playbook_course)

    return if @participant_sync_info.is_dropped?

    @participant_sync_info.user.add_role @participant_sync_info.lc_playbook_course_role, local_section
  end

end
