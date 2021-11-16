# frozen_string_literal: true
require 'canvas_api'
require 'salesforce_api'

# A helper service to perform the logic that makes sure an Enrolled Fellow or
# Teaching Assistant is in the proper "TA Caseload(name)" Canvas sections.
# These sections allow TAs to filter the gradebook down to only the Fellows
# they are responsible for grading.
class SyncTaCaseloadForParticipant

  TA_CASELOAD_SECTION_PREFIX = 'TA Caseload'

  # TODO: pass in the existing canvas_sections in this course (https://app.asana.com/0/1201131148207877/1201348317908955)
  # and the enrollments for this user (https://app.asana.com/0/1201131148207877/1201348317908956)
  # as an optimization

  def initialize(user, salesforce_participant, salesforce_program)
    unless salesforce_participant.status == SalesforceAPI::ENROLLED
      raise ArgumentError.new("Participant #{salesforce_participant} must be Enrolled")
    end
    unless salesforce_participant.role == SalesforceAPI::FELLOW || salesforce_participant.role == SalesforceAPI::TEACHING_ASSISTANT
      raise ArgumentError.new("Participant #{salesforce_participant} must be a Fellow or Teaching Assistant")
    end

    @user = user
    @salesforce_participant = salesforce_participant
    @salesforce_program = salesforce_program
    @accelerator_canvas_course_id = salesforce_program.fellow_course_id
  end

  # 1) Finds all existing enrollments that start with "TA Caseload" and compares that to the desired enrollments
  # 2) For any TA Caseload enrollments in Canvas but not in the desired list, drop them
  # 3) For any TA Caseload enrollments not in Canvas but in the desire list, enroll them.
  def run
    existing_ta_caseload_section_names = current_ta_caseload_enrollments.keys
    Honeycomb.add_field('ta_caseload_section_names.existing', existing_ta_caseload_section_names)

    if @salesforce_participant.teaching_assistant_sections.blank? && current_ta_caseload_enrollments.blank?
      Honeycomb.add_field('sync_ta_caseload_for_participant.skip_reason', 'No TA Caseload enrollments')
      Rails.logger.debug("Skipping TA Caseload sync for #{@user.email}. No TA Caseload enrollments")
      return
    end

    new_ta_caseload_section_names = (ta_caseload_section_names - existing_ta_caseload_section_names)
    Honeycomb.add_field('ta_caseload_section_names.new', new_ta_caseload_section_names)

    old_ta_caseload_section_names = (existing_ta_caseload_section_names - ta_caseload_section_names)
    Honeycomb.add_field('ta_caseload_section_names.old', old_ta_caseload_section_names)

    if new_ta_caseload_section_names.blank? && old_ta_caseload_section_names.blank?
      Honeycomb.add_field('sync_ta_caseload_for_participant.skip_reason', 'No TA Caseload enrollment changes')
      Rails.logger.debug("Skipping TA Caseload sync for #{@user.email}. No TA Caseload enrollment changes")
      return
    end

    new_ta_caseload_section_names.each { |section_name|
      canvas_section = find_or_create_section(section_name)
      canvas_client.enroll_user_in_course(
        @user.canvas_user_id, @accelerator_canvas_course_id, enrollment_role, canvas_section.id, true
      )
    }

    old_ta_caseload_section_names.each { |section_name|
      enrollment_to_delete = current_ta_caseload_enrollments[section_name]
      canvas_client.delete_enrollment(enrollment: enrollment_to_delete)
    }
  end

private

  def ta_caseload_section_names
    return @ta_caseload_section_names if @ta_caseload_section_names
    @ta_caseload_section_names = @salesforce_participant.teaching_assistant_sections.map { |tasect|
      "#{TA_CASELOAD_SECTION_PREFIX}(#{tasect})"
    }
    Honeycomb.add_field('ta_caseload_section_names', @ta_caseload_section_names)
    @ta_caseload_section_names
  end

  # Returns a hash of the section name to the enrollment struct for all TA Caseload
  # sections the user is currently enrolled in.
  def current_ta_caseload_enrollments
    return @current_ta_caseload_enrollments if @current_ta_caseload_enrollments

    current_enrollments = canvas_client
      .find_enrollments_for_course_and_user(@accelerator_canvas_course_id, @user.canvas_user_id)

   if current_enrollments
      @current_ta_caseload_enrollments = current_enrollments.filter_map { |enrollment_struct|
        name = canvas_sections.select { |s| s.id == enrollment_struct.section_id }.first&.name
        if name&.start_with?(TA_CASELOAD_SECTION_PREFIX)
          [name, enrollment_struct]
        end
      }.to_h
    else
      @current_ta_caseload_enrollments = {}
    end
  end

  def canvas_sections
    return @canvas_sections if @canvas_sections
    @canvas_sections = canvas_client.find_sections_by_course_id(@accelerator_canvas_course_id)
  end

  def find_or_create_section(section_name)
    canvas_section = canvas_sections.select{ |section| section.name == section_name }&.first
    if canvas_section.nil?
      canvas_section = canvas_client.create_lms_section(course_id: @accelerator_canvas_course_id, name: section_name)
      canvas_sections << canvas_section
    end
    canvas_section
  end

  def enrollment_role
    if @salesforce_participant.role == SalesforceAPI::TEACHING_ASSISTANT
      RoleConstants::TA_ENROLLMENT
    else
      RoleConstants::STUDENT_ENROLLMENT
    end
  end

  def canvas_client
    CanvasAPI.client
  end

end
