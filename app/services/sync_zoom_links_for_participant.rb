# frozen_string_literal: true
require 'salesforce_api'
require 'zoom_api'

class SyncZoomLinksForParticipant

  ZOOM_HOST_LINK_MESSAGE = 'NONE: cannot generate Zoom link for a Host of the meeting'

  # Pass the force_update parameter set to true if something core about the meeting
  # changed, like the password, where the link needs to be re-generated even if nothing
  # about the Participant changed.
  #
  # @param [ParticipantSyncInfo::Diff] participant_sync_info: a sync info diff that holds
  #      both the old and new values that impact a participant sync
  def initialize(participant_sync_info, force_update = false)
    @participant_sync_info = participant_sync_info
    @force_update = force_update
  end

  def run
    Honeycomb.start_span(name: 'sync_zoom_links_for_participant.run') do
      @participant_sync_info.add_to_honeycomb_span()
      return false unless @force_update || @participant_sync_info.zoom_info_changed?
      set_zoom_link_infos()
      assign_zoom_links if @participant_sync_info.is_enrolled?
      unassign_zoom_links unless @participant_sync_info.is_enrolled?
    rescue  ZoomAPI::TooManyRequestsError => e
      # This happens if you try to hit the API for a given email / meeting pair more than
      # 3 times in a day. Just skip and wait until tomorrow and it should work.
      Sentry.capture_exception(e)
      Honeycomb.add_field('sync_zoom_links_for_participant.skip_reason', e.message)
      Rails.logger.debug(e.message)
    end
  end

private

  def assign_zoom_links
    Rails.logger.debug("Started Zoom links sync for: #{@participant_sync_info.email}")

    # nil means don't change the Salesforce value
    new_join_link1 = nil
    new_join_link2 = nil

    # Clear out the links in Salesforce if the meeting was removed.
    new_join_link1 = '' if clear_out_meeting_1_link?
    new_join_link2 = '' if clear_out_meeting_2_link?

    # If changes to the Participant happen that could effect the Zoom link to change happen,
    # call into the ZoomAPI to get the new link
    registrant1 = register_participant(@new_zoom_link_info_1) if generate_zoom_meeting_1_link?
    registrant2 = register_participant(@new_zoom_link_info_2) if generate_zoom_meeting_2_link?
    new_join_link1 = registrant1['join_url'] if registrant1
    new_join_link2 = registrant2['join_url'] if registrant2

    links_changed = !new_join_link1.nil? || !new_join_link2.nil?
    Honeycomb.add_field('sync_zoom_links_for_participant.changed?', links_changed)

    if links_changed
      Rails.logger.debug('  - Links changed. Updating Salesforce with new links')
      SalesforceAPI.client.update_zoom_links(@participant_sync_info.sfid, new_join_link1, new_join_link2)

      # TODO: if the change was because the meeting_id changed or the email changed, a new registrant
      # will be created and the old one will still be in there and working. Need to delete the old
      # one in this scenario so only the new one works. I think we can use the registrantX['registrant_id'
      # field to detect this.
      # https://app.asana.com/0/1201131148207877/1201279111925854
    else
      Rails.logger.debug('  - Skipping Salesforce update. No changes')
    end

    # Save the latest ZoomLinkInfos so that we can determine if we need to run the sync next time or not.
    # Note that we do this regardless of whether or not links_changed in SF. They could be unchanged in
    # the following scenarios and if we didn't save the new info we'd keep calling into the ZoomAPI
    # on every sync (there is a limit of 3 per day per registrant)
    # - The ZoomLinkInfo(s) could fail to save. If it was temporary, the next sync would save them. Otherwise,
    #   if there was a bug or bad data it would keep failing which we'd want to see and fix.
    # - The first_name (with prefix) or last_name could change and return the same Zoom link. The name you see
    #   in Zoom gets updated, but the link doesn't change.
    create_or_update_link_infos(registrant1, registrant2)
  end

  def unassign_zoom_links
    Rails.logger.debug("Unassigning Zoom links if necessary for: #{@participant_sync_info.email}")
    cancellation_1 = nil
    if @existing_zoom_link_info_1.present?
      cancellation_1 = cancel_registration(@existing_zoom_link_info_1.meeting_id)
      # delete the ZoomLinkInfo so that if future changes to their name, etc that are
      # considered a Zoom info change will be a NOOP and not keept trying to re-cancel
      @existing_zoom_link_info_1.destroy!
    end
    cancellation_2 = nil
    if @existing_zoom_link_info_2.present?
      cancellation_2 = cancel_registration(@existing_zoom_link_info_2.meeting_id)
      @existing_zoom_link_info_2.destroy!
    end

    cancellations_happened = (cancellation_1 || cancellation_2)
    Honeycomb.add_field('sync_zoom_links_for_participant.cancelled?', cancellations_happened)

    if cancellations_happened
      Rails.logger.debug('  - Registrations cancelled. Updating Salesforce to clear out links')
      SalesforceAPI.client.update_zoom_links(@participant_sync_info.id, '', '')
    else
      Rails.logger.debug('  - Skipping Salesforce update. No changes')
    end
  end

  def register_participant(new_zoom_info)
    Honeycomb.start_span(name: 'sync_zoom_links_for_participant.register_participant') do
      Honeycomb.add_field('zoom_link_info.meeting_id', new_zoom_info.meeting_id)
      @participant_sync_info.add_to_honeycomb_span()
      Rails.logger.debug("  - Generating new #{new_zoom_info.salesforce_meeting_id_attribute} for " +
                         "'#{new_zoom_info.first_name} #{new_zoom_info.last_name}'")

      result = ZoomAPI.client.add_registrant(
        new_zoom_info.meeting_id,
        new_zoom_info.email,
        new_zoom_info.first_name_with_prefix,
        new_zoom_info.last_name,
      )
      new_zoom_info.registrant_id = result['registrant_id']
      Honeycomb.add_field('zoom_link_info.registrant_id', new_zoom_info.registrant_id)
      return result

    rescue ZoomAPI::HostCantRegisterForZoomMeetingError => e
      # This happens normally when staff have Participants, so just skip and don't error out.
      # Set the link to the error message so we store that in Salesforce
      Honeycomb.add_field('sync_zoom_links_for_participant.skip_reason', e.message)
      Rails.logger.debug(e.message)
      return { 'error' => true, 'join_url' => ZOOM_HOST_LINK_MESSAGE }
    end
  end

  def cancel_registration(meeting_id)
    Honeycomb.start_span(name: 'sync_zoom_links_for_participant.cancel_registration') do
      Honeycomb.add_field('zoom_link_info.meeting_id', meeting_id)
      @participant_sync_info.add_to_honeycomb_span()
      Rails.logger.debug("  - Cancelling registration for Meeting Id: #{meeting_id}, Email: #{@participant_sync_info.email}")
      # TODO: cutover cancel_registrants to delete_registrant so that a cancellation email doesn't go out.
      # https://app.asana.com/0/1201131148207877/1200865724027633
      ZoomAPI.client.cancel_registrants(meeting_id, [@participant_sync_info.email])
    rescue ZoomAPI::ZoomMeetingDoesNotExistError => e
      # If the meeting has been deleted (b/c it's over most likely), just go ahead and say
      # that the registration has been cancelled since the link is useless anyway.
      Honeycomb.add_field('sync_zoom_links_for_participant.skip_reason', e.message)
      Rails.logger.debug(e.message)
    end

    return true
  end

  def set_zoom_link_infos
    zoom_link_infos = ZoomLinkInfo.where(salesforce_participant_id: @participant_sync_info.sfid)

    # The Zoom link info from the last time they were synced
    @existing_zoom_link_info_1 = zoom_link_infos.find_by(salesforce_meeting_id_attribute: :zoom_meeting_id_1)
    Honeycomb.add_field('sync_zoom_links_for_participant.link_info_1.existing', @existing_zoom_link_info_1.inspect)
    @existing_zoom_link_info_2 = zoom_link_infos.find_by(salesforce_meeting_id_attribute: :zoom_meeting_id_2)
    Honeycomb.add_field('sync_zoom_links_for_participant.link_info_2.existing', @existing_zoom_link_info_2.inspect)

    # The Zoom link info for the current Participant information in Salesforce.
    @new_zoom_link_info_1 = ZoomLinkInfo.parse(@participant_sync_info, :zoom_meeting_id_1)
    Honeycomb.add_field('sync_zoom_links_for_participant.link_info_1.new', @new_zoom_link_info_1.inspect)
    @new_zoom_link_info_2 = ZoomLinkInfo.parse(@participant_sync_info, :zoom_meeting_id_2)
    Honeycomb.add_field('sync_zoom_links_for_participant.link_info_2.new', @new_zoom_link_info_2.inspect)
  end

  # Note that a force_update doesn't actually update the link unless other info has changed,
  # like the password for the meeting for example.
  def generate_zoom_meeting_1_link?
    return false unless zoom_meeting_1_configured?
    return true if @force_update
    return true if @existing_zoom_link_info_1.blank?
    if @existing_zoom_link_info_1.registrant_details_match?(@new_zoom_link_info_1)
      return false
    else
      return true
    end
  end

  def generate_zoom_meeting_2_link?
    return false unless zoom_meeting_2_configured?
    return true if @force_update
    return true if @existing_zoom_link_info_2.blank?
    if @existing_zoom_link_info_2.registrant_details_match?(@new_zoom_link_info_2)
      return false
    else
      return true
    end
  end

  def clear_out_meeting_1_link?
    return false if zoom_meeting_2_configured?
    return true if @participant_sync_info.zoom_meeting_id_1_changed?
    false
  end

  def clear_out_meeting_2_link?
    return false if zoom_meeting_2_configured?
    return true if @participant_sync_info.zoom_meeting_id_2_changed?
    false
  end

  # Is this meeting configured in Salesforce? It is if the Meeting ID is set on the
  # Cohort Schedule, which menas we should be registering participants in the
  # meeting and creating unique links for them to join the meeting
  def zoom_meeting_1_configured?
    @participant_sync_info.zoom_meeting_id_1.present?
  end

  def zoom_meeting_2_configured?
    @participant_sync_info.zoom_meeting_id_2.present?
  end

  def create_or_update_link_infos(registrant1, registrant2)
    upsert_data = []
    upsert_data << @new_zoom_link_info_1.attributes.except('id', 'created_at', 'updated_at') if registrant1 && registrant1['error'].blank?
    upsert_data << @new_zoom_link_info_2.attributes.except('id', 'created_at', 'updated_at') if registrant2 && registrant2['error'].blank?

    if upsert_data.present?
      begin
        ZoomLinkInfo.transaction do
          ZoomLinkInfo.upsert_all(upsert_data, unique_by: [:salesforce_participant_id, :salesforce_meeting_id_attribute])
        end
      rescue ActiveRecord::RecordNotUnique => e
        Sentry.capture_exception(e)

        if e.message.include?('violates unique constraint "index_zoom_link_infos_on_registrant_id"')
          registrant_ids = upsert_data.map {|r| r['registrant_id']}
          existing_zoom_link_infos = ZoomLinkInfo.where(registrant_id: registrant_ids)
          raise unless existing_zoom_link_infos.exists?
          Honeycomb.add_field(
            'alert.sync_zoom_links_for_participant.zoom_link_info_duplicate',
            "Error for Participant ID: '#{@participant_sync_info.sfid}, email: #{@participant_sync_info.email}, error: #{e.message}. Deleting ZoomLinkInfos with registrant_ids: #{registrant_ids}"
          )
          existing_zoom_link_infos.destroy_all
          # Adds in upsert data for the second participant when there are duplicates because
          # it deletes ZoomLinkInfo already in the table for the duplicate registrant_id
          # so that it can add in the data here. Sending the alert above to make it known
          # there might be a duplicate participant.
          ZoomLinkInfo.upsert_all(upsert_data, unique_by: [:salesforce_participant_id, :salesforce_meeting_id_attribute])
        else
          raise
        end
      end
    end
  end
end
