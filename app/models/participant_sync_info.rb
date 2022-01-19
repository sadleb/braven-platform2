# frozen_string_literal: true

require 'delegate'

# Represents information about a Participant that could impact what needs to
# be synced from Salesforce to Platform, Canvas, Zoom, etc.
# On successful sync, we store one of these in the database so that future syncs
# can quickly determine whether the sync logic needs to be run or not depending
# on if there were any changes to the attributes.
class ParticipantSyncInfo < ApplicationRecord

  # type cast these from strings to symbols to make the code cleaner
  attribute :role, :symbol
  attribute :status, :symbol

  # We use this in conjunction with the HerokuConnect models and this makes it easier to use.
  def self.primary_key
    'sfid';
  end

  # Define a module with a scope to be included in the HerokuConnect::Participant model.
  # It is responsbile for doing a fancy join / query that efficiently selects
  # the exact attributes used to initialize one of these ParticipantSyncInfo models
  # using the current Salesforce data.
  module SyncScope
    def self.included(base)
      base.class_eval do

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
            'participant__c.contact__c AS contact_id',
            'recordtype.name AS role',
            'participant__c.status__c AS status',
            'program__c.canvas_cloud_accelerator_course_id__c AS canvas_accelerator_course_id',
            'program__c.canvas_cloud_lc_playbook_course_id__c AS canvas_lc_playbook_course_id',
            'cohort__c.name AS cohort_section_name',
            'cohortschedule__c.webinar_registration_1__c AS zoom_meeting_id_1',
            'cohortschedule__c.webinar_registration_2__c AS zoom_meeting_id_2',

            # Fields to know if the Zoom Prefix has changed
            'dlrs_lc1_first_name__c AS lc1_first_name',
            'dlrs_lc1_last_name__c AS lc1_last_name',
            'dlrs_lc_firstname__c AS lc2_first_name',
            'dlrs_lc_lastname__c AS lc2_last_name',
            'dlrs_lc_total__c AS lc_count',

            # Fields to know if the CohortSchedule#canvas_section_name changed
            'cohortschedule__c.weekday__c AS cohort_schedule_weekday',
            'cohortschedule__c.time__c AS cohort_schedule_time',

            # Fields to know their Candidate Role (aka Participant Role aka Volunteer Role)
            # It's called coach_partner_role__c in SF for legacy reasons, but it's used generically
            # now to qualify TA's and LC's RecordTypes further.
            'candidate__c.coach_partner_role__c AS candidate_role_select',

            # Fields to know if the TaAssignments changed
            TA_NAMES_SQL_SUBQUERY,
            TA_CASELOAD_NAME_SQL_SUBQUERY,
          )
          .where(
            recordtype: { name: [
              HerokuConnect::Participant::Role::FELLOW,
              HerokuConnect::Participant::Role::LEADERSHIP_COACH,
              HerokuConnect::Participant::Role::TEACHING_ASSISTANT
            ]}
          )
        }
      end
    end # self.included

    TA_NAMES_SQL_SUBQUERY = <<~SQL
      (
        SELECT array_agg(CONCAT(c.firstname, ' ', c.lastname))
        FROM ta_assignment__c AS t
          INNER JOIN participant__c p ON t.ta_participant__c = p.sfid
          INNER JOIN contact c ON p.contact__c = c.sfid
        WHERE t.fellow_participant__c = participant__c.sfid
      ) AS ta_names
    SQL

    TA_CASELOAD_NAME_SQL_SUBQUERY = <<~SQL
      (
        SELECT CONCAT(contact.firstname, ' ', contact.lastname)
        FROM ta_assignment__c AS tas
        WHERE ta_participant__c = participant__c.sfid
        LIMIT 1
      ) AS ta_caseload_name
    SQL
  end # SyncScope

  # TODO: actually implement the sync and move this proof of concept to the
  # sync_current_and_future rake task and SyncSalesforceProgram service.
  # The sync will now pass a ParticipantSyncInfoDiff object through the layers of the various
  # sync services after determining that something changed that impacts the sync.
  # https://app.asana.com/0/1201131148207877/1201453841518463
  def self.run_sync_poc(max_run_time_seconds)
    start_time = Time.now.utc

    Honeycomb.start_span(name: 'run_sync_poc.all_programs') do
      HerokuConnect::Program.current_and_future_program_ids.each do |program_id|

        Honeycomb.start_span(name: 'run_sync_poc.program') do
          Honeycomb.add_field('salesforce.program.id', program_id)

          new_sync_participant_ids = []
          new_sync_infos = []
          last_sync_infos = []
          participants_to_sync = []

          # Get all the current info related to a participant that needs to be synced.
          Honeycomb.start_span(name: 'run_sync_poc.new_sync_infos') do

            # TODO: one idea to make this more efficient is to store a hash of the attribute values
            # in a column on ParticipantSyncInfo and have the query only return sync_info's that are
            # new or have changed by joining participant to participant_sync_info on the sfids and using
            # WHERE clause for when the hashed values don't match. This way, we wouldn't have to load all
            # the actual attributes into memory just to know if they need to be synced. I started trying to do this,
            # BUT, it's not possible to do in a dev env b/c the HerokuConnect tables are on the staging database
            # so we can't join to the local database. Let's punt this until memory issues actually become a problem.
            # Note: we could still use a hash of the attributes to avoid loading last_sync_infos that have't changed
            # but it's not worth all the complexity / overhead unless we can get it to only return changed participants
            # at the DB level
            new_sync_infos = HerokuConnect::Participant.sync_info
              .where(program__c: program_id)

            new_sync_participant_ids = new_sync_infos.map(&:sfid)
            puts "### RUN_POC: new_sync_infos = #{new_sync_participant_ids.count}"
            Honeycomb.add_field('participant_sync_info.new.count', new_sync_participant_ids.count)
          end

          # Get the most recently synced info.
          Honeycomb.start_span(name: 'run_sync_poc.last_sync_infos') do
            last_sync_infos = ParticipantSyncInfo.where(sfid: new_sync_participant_ids).index_by(&:sfid)
            puts "### RUN_POC: last_sync_info_count = #{last_sync_infos.count}"
            Honeycomb.add_field('participant_sync_info.last.count', last_sync_infos.count)
          end

          # Figure out which participants need to be synced due to changes.
          Honeycomb.start_span(name: 'run_sync_poc.get_changed_participants') do
            new_sync_infos.find_each do |participant|
              last_sync_info = last_sync_infos[participant.sfid]
              new_sync_info = ParticipantSyncInfo.new(participant.attributes)
              pdiff = Diff.new(last_sync_info, new_sync_info)
              has_changed = pdiff.changed?
              #puts "### RUN_POC: sfid: #{participant.sfid}- pdiff.changed? = #{has_changed}"
              if has_changed
                Honeycomb.start_span(name: 'run_sync_poc.changed_participant') do
                  pdiff.add_to_honeycomb_span()
                  puts "### RUN_POC: pdiff = #{pdiff.inspect}"
                  puts "### RUN_POC: last_sync_info = #{last_sync_info.inspect}"
                  puts "### RUN_POC: new_sync_info = #{new_sync_info.inspect}"
                end
              end
              participants_to_sync << pdiff if has_changed
            end
            puts "### RUN_POC: participants_to_sync_count = #{participants_to_sync.count}"
            Honeycomb.add_field('participant_sync_info.changed.count', participants_to_sync.count)
          end

          Honeycomb.add_field('participant_sync_info.last.count', last_sync_infos.count)
          Honeycomb.add_field('participant_sync_info.new.count', new_sync_participant_ids.count)
          Honeycomb.add_field('participant_sync_info.changed.count', participants_to_sync.count)

          # Help these get garbage collected sooner while we work on the actual sync
          new_sync_infos = nil
          new_sync_participant_ids = nil
          last_sync_infos = nil

          # TODO: kick off the sync with the final participants_to_sync list,
          # This just pretends the sync workd for this POC and saves the new values as "last synced"

          participants_to_sync.each { |p|
            Honeycomb.start_span(name: 'run_sync_poc.sync_participant') do
              elapsed_seconds = Time.now.utc - start_time
              if elapsed_seconds > max_run_time_seconds
                puts "### RUN_POC: exiting early b/c sync has been running for #{elapsed_seconds} and the max run_time is #{max_run_time_seconds}"
                Honeycomb.add_field('run_sync_poc.exited_early?', true)
                # The time format used is the same in libhoney:
                # https://github.com/honeycombio/libhoney-rb/blob/3607446da676a59aad47ff72c3e8d749f885f0e9/lib/libhoney/transmission.rb#L187
                Honeycomb.add_field('run_sync_poc.exit_time', Time.now.utc.iso8601(3))
                return
              end

              # TODO: mimic an actual sync taking time to process everyone. We're going to run this
              # in prod for a bit before actually hooking it up and I want to be able to setup some Honeycomb
              # queiries to see how long things take when real changes happen, assuming a sync for each of those
              # can take a bit.
              puts "  #### RUN_POC: sleeping 4 seconds, pretending to sync. Let's query this span and aggregate the time spent which is dependant on the # changes"
              sleep 4
              p.new_sync_info.updated_at = Time.now.utc
              ParticipantSyncInfo.upsert(p.attributes.except('id', 'created_at'), unique_by: :sfid)
            end
          }

        end
      end # for each program
    end
  end # run_sync_poc

  # If the Cohort isn't set (aka Cohort mapping hasn't happened yet), use the section
  # name for the Cohort Schedule as a placeholder section that we setup before they are
  # mapped to their real cohort in the 2nd or 3rd week.
  def primary_enrollment_canvas_section_name
    cohort_section_name || # E.g. SJSU Brian (Tues)
      cohort_schedule_canvas_section_name # E.g. 'Monday, 7:00'
  end

  # The name of the Canvas section that corresponds to this Cohort Schedule.
  # These sections are where we setup the due dates and when Cohort mapping happens
  # folks are moved from the cohort_schedule_canvas_section_name to their
  # primary_enrollment_canvas_section_name and the due dates are copied over.
  def cohort_schedule_canvas_section_name
    HerokuConnect::CohortSchedule.calculate_canvas_section_name(cohort_schedule_weekday, cohort_schedule_time)
  end

  # If there is a "Candidate Role" set using "Candidate Role Select" dropdown
  # (stored in the coach_partner_role__c field for legacy reasons), use that.
  # Otherwise, use the `RecordType.name` of the Candidate (aka Teaching Assistant, Fellow, etc)
  def candidate_role
    HerokuConnect::Candidate.calculate_candidate_role(candidate_role_select, role)
  end

  # Returns true if that are any TaAssignment__c Salesforce records mapped to this Participant
  # meaning they should be in the corresponding TA Casload(TA Name) section in Canvas.
  def assigned_to_canvas_ta_caseload_section?
    ta_caseload_name.present? || ta_names.present?
  end

  # Returns a list of Contact full names for each TA Caseload(full_name) section they should
  # be addded to in Canvas. Reimplements the logic for the :teaching_assistant_sections
  # field returned from the SalesforceAPI#get_participants() APEX endpoint.
  def teaching_assistant_full_names
    ret = []
    ret << ta_caseload_name if ta_caseload_name.present?
    ret += ta_names if ta_names.present?
    ret
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
      @changed = nil
      @contact_changed = nil
      @enrollment_changed = nil
      @zoom_info_changed = nil
      @ta_assignments_changed = nil
    end

    def changed?
      @changed ||= (
        contact_changed? ||
        enrollment_changed? ||
        zoom_info_changed? ||
        ta_assignments_changed?
      )
    end

    def contact_changed?
      @contact_changed ||= (
        contact_id != @last_sync_info&.contact_id ||
        email != @last_sync_info&.email ||
        first_name != @last_sync_info&.first_name ||
        last_name != @last_sync_info&.last_name
      )
    end

    def enrollment_changed?
      @enrollment_changed ||= (
        role != @last_sync_info&.role ||
        status != @last_sync_info&.status ||
        primary_enrollment_canvas_section_name != @last_sync_info&.primary_enrollment_canvas_section_name ||
        candidate_role != @last_sync_info&.candidate_role ||
        canvas_accelerator_course_id != @last_sync_info&.canvas_accelerator_course_id ||
        canvas_lc_playbook_course_id != @last_sync_info&.canvas_lc_playbook_course_id
      )
    end

    def zoom_info_changed?
      @zoom_info_changed ||= (
        zoom_meeting_id_1 != @last_sync_info&.zoom_meeting_id_1 ||
        zoom_meeting_id_2 != @last_sync_info&.zoom_meeting_id_2 ||
        lc1_first_name != @last_sync_info&.lc1_first_name ||
        lc1_last_name != @last_sync_info&.lc1_last_name ||
        lc2_first_name != @last_sync_info&.lc2_first_name ||
        lc2_last_name != @last_sync_info&.lc2_last_name ||
        contact_changed?
      )
    end

    def ta_assignments_changed?
      @ta_assignments_changed ||= (
        ta_names != @last_sync_info&.ta_names ||
        ta_caseload_name != @last_sync_info&.ta_caseload_name
      )
    end

    def add_to_honeycomb_span
      Honeycomb.add_field('participant_sync_info.changed?', changed?)
      Honeycomb.add_field('participant_sync_info.contact_changed?', contact_changed?)
      Honeycomb.add_field('participant_sync_info.enrollment_changed?', enrollment_changed?)
      Honeycomb.add_field('participant_sync_info.zoom_info_changed?', zoom_info_changed?)
      Honeycomb.add_field('participant_sync_info.ta_assignments_changed?', ta_assignments_changed?)
      @new_sync_info.add_to_honeycomb_span('.new')
      if changed?
        @last_sync_info.add_to_honeycomb_span('.last') if @last_sync_info.present?
        Honeycomb.add_field('participant_sync_info.last_sync_info.exists?', false) if @last_sync_info.blank?
      end
    end
  end
end
