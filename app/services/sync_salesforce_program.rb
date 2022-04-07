# frozen_string_literal: true
require 'canvas_api'
require 'sis_import'
require 'sis_import_data_set'
require 'sis_import_batch_mode'
require 'sis_import_status'
require 'zoom_api'

# Syncs all Participants from the specified Salesforce Program across
# all applications like Platform and Canvas and Zoom.
#
# Note: Discord is separate b/c it's a bot.
#
# This service uses the Canvas SIS Imports API for the Canvas portion of the
# sync. See:
# - https://canvas.instructure.com/doc/api/sis_imports.html
# - https://canvas.instructure.com/doc/api/file.sis_csv.html
class SyncSalesforceProgram
  include Rails.application.routes.url_helpers

  attr_reader :failed_participants, :count

  class UserSetupError < StandardError; end
  class DuplicateContactError < UserSetupError; end
  class MissingContactError < UserSetupError; end
  class DuplicateParticipantError < StandardError; end
  class ExitedEarlyError < StandardError; end
  class MissingCourseModelsError < StandardError; end
  class MissingProgramError < StandardError; end
  class NoCohortScheduleError < StandardError; end
  class SisImportFailedError < StandardError; end
  class SyncParticipantsError < StandardError; end

  # These SectionSetupErrors are for things that impact having the Canvas and local Section
  # properly created. They are not for issues with Section enrollment for an individual
  # Participant
  class SectionSetupError < StandardError; end
  class CreateSectionError < SectionSetupError; end
  class MissingSectionError < SectionSetupError; end

  FailedParticipantInfo = Struct.new(:participant_id, :email, :first_name, :last_name, :error_detail, keyword_init: true)

  def initialize(salesforce_program, max_duration_seconds, force_canvas_update=false, force_zoom_update=false)
    @salesforce_program = salesforce_program
    @max_duration_seconds = max_duration_seconds
    @force_canvas_update = force_canvas_update
    @force_zoom_update = force_zoom_update
    @contact_ids_to_participants = {}
    @failed_participants = []
    @synced_new_canvas_changes = false
  end

  # Handles all syncing logic for all Participants in a Program, such as:
  # 1. creating them when they become Enrolled
  # 2. syncing their email and other Contact info
  # 3. moving them between sections if their enrollment changes
  # 4. unenrolling them if they become Dropped
  # 5. adding them to the proper TA Caseload section
  # 6. syncing their Zoom links
  #
  # Note: Discord is separate b/c it's a bot.
  def run
    @start_time = Time.now.utc
    Honeycomb.start_span(name: 'sync_salesforce_program.run') do
      @salesforce_program.add_to_honeycomb_trace()
      Honeycomb.add_field('sync_salesforce_program.force_canvas_update', @force_canvas_update)
      Honeycomb.add_field('sync_salesforce_program.force_zoom_update', @force_zoom_update)
      Rails.logger.debug("Started sync for Program Id: #{@salesforce_program.sfid}")

      if @salesforce_program.accelerator_course.blank? || @salesforce_program.lc_playbook_course.blank?
        msg = "Missing local Course models for Salesforce Program ID: #{@salesforce_program.sfid}"
        Honeycomb.add_alert('missing_local_courses', msg)
        Honeycomb.add_field('sync_salesforce_program.skip_reason', msg)
        raise MissingCourseModelsError, msg
      end

      @participants = ParticipantSyncInfo.diffs_for_program(@salesforce_program)
      @count = @participants.count
      Honeycomb.add_field('sync_salesforce_program.participants.count', @count)

      if @force_canvas_update == false && @force_zoom_update == false && @participants.none? { |p| p.changed? }
        msg = 'No Participant changes.'
        Honeycomb.add_field('sync_salesforce_program.skip_reason', msg)
        Rails.logger.debug("  Skipping sync for #{@salesforce_program.sfid}. #{msg}")
        return self
      end

      sync_local_program_id()

      if @force_canvas_update
        @sis_import = SisImportBatchMode.new(@salesforce_program)
      else
        diffing_mode_on = use_diffing_mode?
        @sis_import = SisImportDataSet.new(@salesforce_program, diffing_mode_on)
      end

      upsert_data = sync_participants()

      # Only send the SIS Import to Canvas if there are new changes that actually synced.
      # This is to prevent continuously sending the same data to Canvas every sync if we
      # have failing Participants that take some time for us to fix the underlying issue.
      # For example, imagine we had one with a duplicate Contact and it took us a day to
      # merge. If no other Participants had changes that actually got through the sync,
      # we'd skip sending the same thing to Canvas that we just sent.
      if @synced_new_canvas_changes
        sis_import_status = @sis_import.send_to_canvas()
        @salesforce_program.courses.update_all(last_canvas_sis_import_id: sis_import_status.sis_import_id)

        # Poll Canvas until the SisImport completes so that other syncs for this Program won't run
        # until then or until we exit early b/c the max duration expires.
        @sis_import_finished_status = sis_import_status.wait_for_import_to_finish do
          raise_if_should_exit_early!
        end
        @sis_import_finished_status.add_to_honeycomb_span()

        raise_if_sis_import_failed!

        save_synced_participants(upsert_data)

        success_count = @count - @failed_participants.count
        Honeycomb.add_field('sync_salesforce_program.participants.success.count', success_count)
        Rails.logger.info("  Finished syncing #{success_count} / #{@count} Participants")
      else
        msg = 'No Participants that needed a sync were successfully synced.'
        Honeycomb.add_field('sync_salesforce_program.skip_reason', msg)
        Rails.logger.warn("  Skipping sync for #{@salesforce_program.sfid}. #{msg}")
        # Let it raise SyncParticipantsError below so we keep seeing the alerts until
        # it's all fixed up.
      end

      unless @failed_participants.empty?
        Rails.logger.error(@failed_participants.inspect)
        raise SyncParticipantsError, "Some participants failed to sync => #{@failed_participants.inspect}"
      end
    end

    self
  end

private

  # Processes all the participants, creating both Canvas and local users and sections when necessary,
  # syncing their Zoom link info, adjusting their local UserRole, and adding all their Canvas enrollment
  # info to the SisImportDataSet
  def sync_participants
    upsert_data = []
    Rails.logger.debug('  Starting to sync Participants')
    @participants.each do |participant|
      Honeycomb.start_span(name: 'sync_salesforce_program.sync_participant') do
        # For individual Participants, if there is an error keep processing the rest
        # and report those that failed back at the end. We don't want issues with a single
        # Participant to prevent the rest from syncing.
        #
        # IMPORTANT: a Participant who already has Canvas access where there is a sync
        # failure specific to them will LOSE access until the error is corrected.

        unless participant.should_sync? # See ParticipantSyncInfo#should_sync? for more info
          msg = 'Participant is not in a syncable state. Maybe they are missing a Cohort Schedule?.'
          Honeycomb.add_field('sync_salesforce_program.participant.skip_reason', msg)
          Rails.logger.debug("  Skipping sync for Participant ID: #{participant.sfid}. #{msg}")
          next
        end

        unique_participant = with_participant_error_handling(participant) do
          raise_if_duplicate_participant!(participant)
        end
        next unless unique_participant

        zoom_sync_success = with_participant_error_handling(participant) do
          # Note that we run this before the enrollment stuff b/c we want to have the Zoom
          # links in Salesforce even if the Participant Canvas sync fails.
          SyncZoomLinksForParticipant.new(participant, @force_zoom_update).run
        end

        canvas_sync_success = with_participant_error_handling(participant) do
          SyncSalesforceParticipant.new(@sis_import, @salesforce_program, participant).run()
          @synced_new_canvas_changes = true if participant.changed?
        end

        # Save the ParticipantSyncInfo back to the database if we fully synced them
        # so they'll be skipped next sync unless something new changes.
        if zoom_sync_success && canvas_sync_success
          participant.new_sync_info.updated_at = Time.now.utc
          upsert_data << participant.attributes.except('id', 'created_at')
        end
      end
    end

    upsert_data
  end

  def with_participant_error_handling(participant, &block)
    block.call()
    return true
  rescue => e
    # These can impact more than just this Participant. Let the whole sync fail if we can't
    # setup the Sections properly.
    raise if e.is_a?(SectionSetupError)

    Sentry.capture_exception(e)
    error_detail = translate_error_to_user_message(e, participant)
    Honeycomb.add_field('error', e.class.name)
    Honeycomb.add_field('error_detail', error_detail)
    @failed_participants << FailedParticipantInfo.new(
      participant_id: participant.sfid,
      email: participant.email,
      first_name: participant.first_name,
      last_name: participant.last_name,
      error_detail: error_detail
    )
    return false
  end

  def raise_if_duplicate_participant!(participant)
    if @contact_ids_to_participants.key?(participant.contact_id)
      original_participant = @contact_ids_to_participants[participant.contact_id]
      msg = <<-EOF
There are duplicate Participants in Salesforce for Contact ID: #{participant.contact_id} in Program ID: #{participant.program_id}.
Open the Participant with ID: #{original_participant.sfid} and use the "Duplicate Check -> Merge" tool to get rid of the duplicate. Make sure and choose Particpant #{original_participant.sfid} as the Master record!

For reference, the duplicate Participant is: #{participant.sfid}.
EOF
      Honeycomb.add_alert('duplicate_participant_error', msg)
      raise DuplicateParticipantError, msg
    end

    @contact_ids_to_participants[participant.contact_id] = participant
  end

  # Once the current SIS Import data is successfully sent to Canvas for a participant,
  # save the ParticipantSyncInfos so that future syncs will be a NOOP until someone
  # has changes that require a new sync.
  def save_synced_participants(upsert_data)
    if upsert_data.present?
      ParticipantSyncInfo.upsert_all(upsert_data, unique_by: :sfid)
      Honeycomb.add_field('sync_salesforce_program.save_synced_participants.success?', true)
    else
      msg = 'All Participants failed to fully sync. Will try again next sync.'
      Honeycomb.add_field('sync_salesforce_program.save_synced_participants.success?', false)
      Honeycomb.add_field('error_detail', msg)
      Rails.logger.info("  For Program ID: #{@salesforce_program.sfid}. #{msg}")
    end
  end

  # Running the sync with diffing mode on is faster. Canvas only processes changes from the prior
  # sync. However, if the last sync failed, we want to turn that off and have Canvas process
  # the full list because Canvas is not smart enough to diff with the last successful run.
  # Turning diffing mode off is also known as "remastering" the data_set.
  def use_diffing_mode?
    Honeycomb.start_span(name: 'sync_salesforce_program.use_diffing_mode?') do
      last_import_id = @salesforce_program.accelerator_course.last_canvas_sis_import_id
      return true unless last_import_id # Only happens the very first time a sync runs for a program

      last_import = CanvasAPI.client.get_sis_import_status(last_import_id)

      # This should always return immediately, but I suppose it's possible the last_import
      # never completed, so let's be safe.
      last_import = last_import.wait_for_import_to_finish()
      last_import.add_to_honeycomb_span() unless last_import.is_success?

      return last_import.is_success?
    end
  end

  def raise_if_sis_import_failed!
    return if @sis_import_finished_status.is_success?

    if @sis_import_finished_status.is_success_with_errors?
      filtered_errors = filter_errors_to_ignore()
      Honeycomb.add_field('sync_salesforce_program.processing_errors.filtered', filtered_errors)
      return if filtered_errors.empty?
    end

    msg = "There was an error syncing Program: '#{@salesforce_program.sfid}'. " +
          "Canvas returned a workflow_state of: '#{@sis_import_finished_status.workflow_state}'. " +
          "For details, look in Honeycomb for: " +
          "name=sync_salesforce_program.run, app.canvas.sis_import.id=#{@sis_import_finished_status.sis_import_id}."

    # If it was an actual Canvas failure and not something wrong with the data, the following will be set:
    import_error_msg = @sis_import_finished_status.error_message
    msg = "#{msg}  Details: #{import_error_msg}" if import_error_msg.present?

    Honeycomb.add_alert('sis_import_failed', msg)

    error = SisImportFailedError.new(msg)

    # This outputs the contents of the .csvs to the log. We can't send these to Honeycomb
    # b/c they can be too big and overflow the 64K max size for a string field causing it
    # to be completely dropped.
    Rails.logger.debug(@sis_import.inspect)
    # These will be truncated at 10KB of data, but it still might be useful.
    Sentry.capture_message(
      "#{error.class.name}\n\n#{msg}\n\n" +
      "#{@sis_import_finished_status.inspect}\n\n#{@sis_import.inspect}"
    )

    raise error
  end

  # As we discover SIS Import errors that we can ignore and consider the sync "successful"
  # add more logic here to filter them out.
  def filter_errors_to_ignore
    @sis_import_finished_status.processing_error_details.filter do |e|

      # Dropping a TA (or someone with admin permissions) results in the following type of error:
      # [["admins.csv","Invalid or unknown user_id 'BVUserId_84_SFContactId_0031100001toonoAAA' for admin"]]
      #
      # I haven't figured out how to prevent this, so just ignore this error for dropped TAs
      if e[:file_name] == SisImport::Filename::ADMINS_CSV &&
         e[:error_type] == SisImportStatus::ErrorType::USER_MISSING

        participant = @contact_ids_to_participants[e[:contact_id]]
        participant.is_enrolled? # don't ignore if enrolled

      else
        true # don't ignore
      end

    end
  end

  # When developing or QA'ing we sometimes change which Courses a given Program is configured for.
  # This updates the local database to match Salesforce for this Program.
  def sync_local_program_id
    return unless @salesforce_program.courses.any? { |c| c.salesforce_program_id != @salesforce_program.sfid }

    # This should be uncommon enough in prod Salesforce that an alert is worthwhile so we
    # can keep an eye on it b/c if the IDs change for an actual launched Program and not a test/QA one
    # that's not good.
    Honeycomb.add_alert('mismatched_program_courses',
      "There is a mismatch between the Courses in Salesforce and the local " +
      "Platform Courses for Program ID: #{@salesforce_program.sfid}. Automatically syncing them."
    )

    # Clear out the courses currently mapped to this salesforce_program_id so we can map the new ones
    old_courses = Course.where(salesforce_program_id: @salesforce_program.sfid)
    old_courses.update_all(salesforce_program_id: nil)
    Honeycomb.add_field('sync_salesforce_program.sync_local_program_id.old_courses', old_courses.inspect)

    @salesforce_program.courses.update_all(salesforce_program_id: @salesforce_program.sfid)
    Honeycomb.add_field('sync_salesforce_program.sync_local_program_id.new_courses', @salesforce_program.courses.inspect)
  end

  def raise_if_should_exit_early!
    elapsed_seconds = Time.now.utc - @start_time
    return if (elapsed_seconds + SisImportStatus::POLLING_WAIT_TIME_SECONDS < @max_duration_seconds)

    msg = "Program sync for #{@salesforce_program.sfid} exiting early after running for #{elapsed_seconds} "+
          "when the max run_time is #{@max_duration_seconds}"
    Rails.logger.warn(msg)
    Honeycomb.add_field_to_trace('sync_salesforce_program.exited_early?', true)
    Honeycomb.add_field('sync_salesforce_program.exited_early.elapsed_seconds', elapsed_seconds)
    # The time format used is the same in libhoney:
    # https://github.com/honeycombio/libhoney-rb/blob/3607446da676a59aad47ff72c3e8d749f885f0e9/lib/libhoney/transmission.rb#L187
    Honeycomb.add_field('sync_salesforce_program.exited_early.time', Time.now.utc.iso8601(3))
    raise ExitedEarlyError, msg
  end

  def translate_error_to_user_message(e, participant)
    error_detail = "#{e.class}: #{e.message}"

    if e.is_a?(DuplicateContactError) ||
       e.is_a?(DuplicateParticipantError) ||
       e.is_a?(MissingContactError) ||
       e.is_a?(UserSetupError) ||
       e.is_a?(ZoomAPI::ZoomMeetingEndedError) ||
       e.is_a?(ZoomAPI::RegistrationNotEnabledForZoomMeetingError) ||
       e.is_a?(ZoomAPI::ZoomMeetingDoesNotExistError) ||
       e.is_a?(ZoomAPI::TooManyRequestsError) ||
       e.is_a?(ZoomAPI::BadZoomRegistrantFieldError)

      error_detail = e.message

    elsif e.is_a?(CanvasAPI::TimeoutError)
      error_detail = e.message << " Until it works this user may have trouble accessing Canvas: #{participant.email}"
    end

    error_detail
  end

  def canvas_client
    CanvasAPI.client
  end
end
