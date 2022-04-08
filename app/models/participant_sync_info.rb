# frozen_string_literal: true

require 'delegate'

# Represents information about a Participant that could impact what needs to
# be synced from Salesforce to Platform, Canvas, Zoom, etc.
# On successful sync, we store one of these in the database so that future syncs
# can quickly determine whether the sync logic needs to be run or not depending
# on if there were any changes to the attributes.
class ParticipantSyncInfo < ApplicationRecord

  # type cast these from strings to symbols to make the code cleaner
  attribute :role_category, :symbol
  attribute :status, :symbol

  # We use this in conjunction with the HerokuConnect models and this makes it easier to use.
  def self.primary_key
    'sfid';
  end

  # Since the fields on this model come from HerokuConnect, it's safer to lookup
  # the User using the Salesforce Contact.Id instead of the Platform User.Id in
  # case there was a failure or delay sending the Platform User.Id to Salesforce.
  belongs_to :user, primary_key: :salesforce_id, foreign_key: :contact_id

  belongs_to :cohort_schedule_section, primary_key: :salesforce_id, foreign_key: :cohort_schedule_id, class_name: Section.name, optional: true
  belongs_to :cohort_section, primary_key: :salesforce_id, foreign_key: :cohort_id, class_name: Section.name, optional: true

  # Define a module with a scope to be included in the HerokuConnect::Participant model.
  # It is responsbile for doing a fancy join / query that efficiently selects
  # the exact attributes used to initialize one of these ParticipantSyncInfo models
  # using the current Salesforce data.
  #
  # PRO-TIP: when debugging, use the `attributes` method for one of these to see the values.
  # E.g. HerokuConnect::Participant.sync_info.find('someID').attributes
  module SyncScope
    def self.included(base)
      base.class_eval do

        # Note: when using a WHERE clause to limit what this scope selects, you need to specify the
        # the columns on the HerokuConnect::Participant table. See heroku_connect/participant_spec.rb
        # for a list of those
        scope :sync_info, -> {
          unscope(:select) # throw away the default_columns scope b/c we're overriding what to select
          .left_joins(:contact, :record_type, :program, :cohort, :cohort_schedule, :candidate)
          .select(
            # IMPORTANT: the column names selected here MUST exactly match the column names on
            # the participant_sync_infos table. If you add / change anything here MAKE SURE
            # and keep them in sync so that ParticipantSyncInfo.new(p.attributes) works with one
            # of these results
            :'participant__c.sfid',
            'contact.firstname AS first_name',
            'contact.lastname AS last_name',
            :'contact.email',
            # HerokuConnect stores this as a double precision type, but we store it as bigint in
            # the Rails database
            'CAST(contact.canvas_cloud_user_id__c AS bigint) AS canvas_user_id',
            # HerokuConnect stores this as a charvar(20), but we store it as bigint in
            # the Rails database
            'CAST(contact.platform_user_id__c AS bigint) AS user_id',
            'participant__c.contact__c AS contact_id',
            'recordtype.name AS role_category',
            'participant__c.status__c AS status',
            'program__c.sfid AS program_id',
            'program__c.canvas_cloud_accelerator_course_id__c AS canvas_accelerator_course_id',
            'program__c.canvas_cloud_lc_playbook_course_id__c AS canvas_lc_playbook_course_id',
            'cohort__c.name AS cohort_section_name',
            'cohort__c.sfid AS cohort_id',
            'cohortschedule__c.webinar_registration_1__c AS zoom_meeting_id_1',
            'cohortschedule__c.webinar_registration_2__c AS zoom_meeting_id_2',
            'cohortschedule__c.sfid AS cohort_schedule_id',

            # Fields to know if the Zoom Prefix has changed
            'dlrs_lc1_first_name__c AS lc1_first_name',
            'dlrs_lc1_last_name__c AS lc1_last_name',
            'dlrs_lc_firstname__c AS lc2_first_name',
            'dlrs_lc_lastname__c AS lc2_last_name',
            'dlrs_lc_total__c AS lc_count',

            # Fields to know if the CohortSchedule#canvas_section_name changed
            'cohortschedule__c.weekday__c AS cohort_schedule_weekday',
            'cohortschedule__c.time__c AS cohort_schedule_time',

            # See Candidate#role for more info on how this is used and what it is.
            'candidate__c.coach_partner_role__c AS candidate_role_select',

            # Fields to know if the Salesforce TaAssignment records changed
            TA_CASELOAD_ENROLLMENTS_SQL_SUBQUERY
          )
          .where(
            recordtype: { name: [
              SalesforceConstants::RoleCategory::FELLOW,
              SalesforceConstants::RoleCategory::LEADERSHIP_COACH,
              SalesforceConstants::RoleCategory::TEACHING_ASSISTANT
            ]}
          )
          .where.not('participant__c.status__c': nil) # ignore folks where we cleared their Status
        }
      end
    end # self.included

    # Returns a JSON blob like the following, one for each TA Caseload enrollment:
    # [
    #   {"ta_name":"Some TA1","ta_participant_id":"a2X11000000nJ5aEAE"},
    #   {"ta_name":"Some TA2","ta_participant_id":"a2X11000000nJ5fEAQ"}
    # ]
    # Access this blob using the 'ta_caseload_enrollments' column like
    # HerokuConnect::Participant.sync_info.find_by(some_condition).ta_caseload_enrollments
    TA_CASELOAD_ENROLLMENTS_SQL_SUBQUERY = <<~SQL
      (
        SELECT json_agg(row_to_json(row))
        FROM
        (
          SELECT DISTINCT ON(ta_participant_id)
            CONCAT(c.firstname, ' ', c.lastname) AS ta_name,
            t.ta_participant__c AS ta_participant_id
          FROM ta_assignment__c AS t
            INNER JOIN participant__c p ON t.ta_participant__c = p.sfid
            INNER JOIN contact c ON p.contact__c = c.sfid
          WHERE
            t.fellow_participant__c = participant__c.sfid OR
            t.ta_participant__c = participant__c.sfid
          ORDER BY ta_participant_id
        ) AS row
      ) AS ta_caseload_enrollments
    SQL

  end # SyncScope

  # Returns a ParticipantSyncInfo::Diff for the specified participant_id.
  # If there is nothing to sync ParticipantSyncInfo::Diff#changed? will be false
  def self.diff_for_id(participant_id)
    # Most up to date info about this Participant
    pinfo = HerokuConnect::Participant.sync_info.find(participant_id)
    current_sync_info = ParticipantSyncInfo.new(pinfo.attributes)

    # Load the previous data that was successfully synced and saved in the database. May be nil
    last_sync_info = ParticipantSyncInfo.find_by(sfid: participant_id)

    ParticipantSyncInfo::Diff.new(last_sync_info, current_sync_info)
  end

  # Returns an array of ParticipantSyncInfo::Diff objects for Participants
  # in the Program.
  #
  # Note: if you try to optimize this by storing a hashed value of the attributes,
  # and comparing against the current hash -> go read this first. It's not really
  # possible to do maintainably: # https://app.asana.com/0/1201131148207877/1201625616556853
  def self.diffs_for_program(program)

    # Get the current values in Salesforce for all the ParticipantSyncInfo columns
    new_sync_participant_ids = []
    new_sync_infos = HerokuConnect::Participant.sync_info.where(program__c: program.sfid).map do |p|
      new_sync_participant_ids << p.sfid
      ParticipantSyncInfo.new(p.attributes)
    end

    # Load the previous values that were successfully synced and saved in the database
    # Note: index_by returns these as { 'sfid' => the_sync_info_model }
    last_sync_infos = ParticipantSyncInfo.where(sfid: new_sync_participant_ids).index_by(&:sfid)

    # Create the diffs. Note that last_sync_info can be nil
    new_sync_infos.map { |new_sync_info|
      last_sync_info = last_sync_infos[new_sync_info.sfid]
      pdiff = ParticipantSyncInfo::Diff.new(last_sync_info, new_sync_info)
    }
  end

  def is_enrolled?
    status == HerokuConnect::Participant::Status::ENROLLED
  end

  def is_dropped?
    status == HerokuConnect::Participant::Status::DROPPED
  end

  def is_completed?
    status == HerokuConnect::Participant::Status::COMPLETED
  end

  def is_mapped_to_cohort?
    cohort_section_name.present?
  end

  def accelerator_course_role
    if role_category == SalesforceConstants::RoleCategory::FELLOW
      RoleConstants::STUDENT_ENROLLMENT
    else
      RoleConstants::TA_ENROLLMENT
    end
  end

  def ta_caseload_role
    if role_category == SalesforceConstants::RoleCategory::FELLOW
      RoleConstants::STUDENT_ENROLLMENT
    elsif role_category == SalesforceConstants::RoleCategory::TEACHING_ASSISTANT
      RoleConstants::TA_ENROLLMENT
    else
      raise ArgumentError.new("Expected a Fellow or Teaching Assistant, not: #{role_category}")
    end
  end

  def has_canvas_staff_permissions?
    role_category == SalesforceConstants::RoleCategory::TEACHING_ASSISTANT
  end

  # The name of the Canvas section that corresponds to this Cohort Schedule.
  # These sections are where we setup the due dates. When Cohort mapping happens
  # folks are added to the Cohort section in Canvas too.
  def cohort_schedule_section_name
    HerokuConnect::CohortSchedule.calculate_canvas_section_name(cohort_schedule_id, cohort_schedule_weekday, cohort_schedule_time)
  end

  def add_to_honeycomb_span(suffix = nil)
    attributes.each_pair { |attr, value| Honeycomb.add_field("participant_sync_info.#{attr}#{suffix}", value.to_s) }
  end

  ###################################
  ###################################

  # Represents a diff b/n the last sync info and the new sync info.
  # Delegates all public methods to the ParticipantSyncInfo class
  # for the new_sync_info used to initialize it.
  #
  # Example of delegation:
  # p = ParticipantSyncInfo::Diff.new(last_sync_info, new_sync_info)
  # p.email == new_sync_info.email
  # => true
  class Diff < Delegator
    attr_accessor :new_sync_info
    # Makes this class act like a ParticipantSyncInfo using the new_sync_info
    # so you can just treat it as one.
    # Inspiration taken from:
    # - https://blog.lelonek.me/how-to-delegate-methods-in-ruby-a7a71b077d99
    # - https://blog.appsignal.com/2019/04/30/ruby-magic-hidden-gems-delegator-forwardable.html
    alias_method :__getobj__, :new_sync_info

    def initialize(last_sync_info, new_sync_info)
      raise ArgumentError.new('new_sync_info is nil') if new_sync_info.nil?
      # Note: last_sync_info can be nil. It just means they haven't ever been successfully synced.

      @last_sync_info = last_sync_info
      @new_sync_info = new_sync_info
    end

    # True if this Participant is in a state where the sync logic should run.
    #
    # We can't enforce Enrolled Participants to have a Cohort Schedule set in Salesforce
    # due to the complex logistics of moving folks from the recruitment stage to enrolled stage.
    # So we just wait until they are given one and then we start syncing them.
    #
    # IMPORTANT: do not save this ParticipantSyncInfo if should_sync? is false.
    # If you did, when they did get a Cohort Schedule then other parts of the
    # sync may not run b/c we think it was already synced.
    def should_sync?
      if requires_cohort_schedule? &&
         cohort_schedule_id.blank? &&
         user_id.blank?

        return false

      else
        return true
      end
    end

    def changed?
      return false unless should_sync?

      (
        contact_changed? ||
        primary_enrollment_changed? ||
        zoom_info_changed? ||
        ta_caseload_sections_changed?
      )
    end

    def contact_changed?
      (
        contact_id != @last_sync_info&.contact_id ||
        email != @last_sync_info&.email ||
        first_name != @last_sync_info&.first_name ||
        last_name != @last_sync_info&.last_name ||
        canvas_user_id != @last_sync_info&.canvas_user_id ||
        user_id != @last_sync_info&.user_id
      )
    end

    def primary_enrollment_changed?
      (
        role_category != @last_sync_info&.role_category ||
        status != @last_sync_info&.status ||
        cohort_id != @last_sync_info&.cohort_id ||
        cohort_schedule_id != @last_sync_info&.cohort_schedule_id ||
        cohort_section_name != @last_sync_info&.cohort_section_name ||
        cohort_schedule_name_changed? ||
        candidate_role_select != @last_sync_info&.candidate_role_select ||
        canvas_accelerator_course_id != @last_sync_info&.canvas_accelerator_course_id ||
        canvas_lc_playbook_course_id != @last_sync_info&.canvas_lc_playbook_course_id
      )
    end

    def ta_caseload_sections_changed?
      (
        status != @last_sync_info&.status ||
        ta_caseload_enrollments != @last_sync_info&.ta_caseload_enrollments
      )
    end

    def enrollments_changed?
      primary_enrollment_changed? || ta_caseload_sections_changed?
    end

    def cohort_schedule_name_changed?
      (
        cohort_schedule_weekday != @last_sync_info&.cohort_schedule_weekday ||
        cohort_schedule_time != @last_sync_info&.cohort_schedule_time
      )
    end

    def zoom_info_changed?
      (
        zoom_meeting_id_1 != @last_sync_info&.zoom_meeting_id_1 ||
        zoom_meeting_id_2 != @last_sync_info&.zoom_meeting_id_2 ||
        lc1_first_name != @last_sync_info&.lc1_first_name ||
        lc1_last_name != @last_sync_info&.lc1_last_name ||
        lc2_first_name != @last_sync_info&.lc2_first_name ||
        lc2_last_name != @last_sync_info&.lc2_last_name ||
        contact_changed? ||
        primary_enrollment_changed?
      )
    end

    def zoom_meeting_id_1_changed?
        zoom_meeting_id_1 != @last_sync_info&.zoom_meeting_id_1
    end

    def zoom_meeting_id_2_changed?
        zoom_meeting_id_2 != @last_sync_info&.zoom_meeting_id_2
    end

    def requires_cohort_schedule?
      (
        role_category == SalesforceConstants::RoleCategory::FELLOW ||
        role_category == SalesforceConstants::RoleCategory::LEADERSHIP_COACH
      )
    end

    # Call this to save the new_sync_info back to the database so that the next sync will
    # skip this Participant if there are no changes.
    def save_successful_sync!
      unless should_sync?
        raise RuntimeError.new(
          "Cannot save a ParticipantSyncInfo for #{@new_sync_info.sfid} b/c should_sync? is false."
        )
      end

      @new_sync_info.updated_at = Time.now.utc
      ParticipantSyncInfo.upsert(@new_sync_info.attributes.except('id', 'created_at'), unique_by: :sfid)
    end

    def add_to_honeycomb_span
      Honeycomb.add_field('participant_sync_info.changed?', changed?)
      Honeycomb.add_field('participant_sync_info.contact_changed?', contact_changed?)
      Honeycomb.add_field('participant_sync_info.primary_enrollment_changed?', primary_enrollment_changed?)
      Honeycomb.add_field('participant_sync_info.zoom_info_changed?', zoom_info_changed?)
      Honeycomb.add_field('participant_sync_info.ta_caseload_sections_changed?', ta_caseload_sections_changed?)
      @new_sync_info.add_to_honeycomb_span('.new')
      if changed?
        @last_sync_info.add_to_honeycomb_span('.last') if @last_sync_info.present?
        Honeycomb.add_field('participant_sync_info.last_sync_info.exists?', false) if @last_sync_info.blank?
      end
      # duplicate some of the above with names that match what we use in other places as a convenience
      Honeycomb.add_field('salesforce.participant.id', sfid)
      Honeycomb.add_field('user.salesforce_id', contact_id)
      Honeycomb.add_field('user.email', email)
      Honeycomb.add_field('user.canvas_user_id', canvas_user_id)
      Honeycomb.add_field('user.id', user_id)
    end
  end

end
