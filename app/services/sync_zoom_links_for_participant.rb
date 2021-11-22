# frozen_string_literal: true
require 'salesforce_api'
require 'zoom_api'

class SyncZoomLinksForParticipant

  ZOOM_HOST_LINK_MESSAGE = 'NONE: cannot generate Zoom link for a Host of the meeting'

  # Pass the force_update parameter set to true if something core about the meeting
  # changed, like the password, where the link needs to be re-generated even if nothing
  # about the Participant changed.
  def initialize(salesforce_participant, force_update = false)
    @salesforce_participant = salesforce_participant
    @force_update = force_update
  end

  def run
    Honeycomb.start_span(name: 'sync_zoom_links_for_participant.run') do
      @salesforce_participant.add_to_honeycomb_span()

      assign_zoom_links if @salesforce_participant.status == SalesforceAPI::ENROLLED
      unassign_zoom_links unless @salesforce_participant.status == SalesforceAPI::ENROLLED
    end
  end

private

  def assign_zoom_links
    Rails.logger.debug("Assigning Zoom links if necessary for: #{@salesforce_participant.email}")

    set_zoom_link_infos()

    existing_join_link1 = @salesforce_participant.zoom_meeting_link_1
    existing_join_link2 = @salesforce_participant.zoom_meeting_link_2

    registrant1 = register_participant(@new_zoom_link_info_1) if generate_zoom_meeting_1_link?
    registrant2 = register_participant(@new_zoom_link_info_2) if generate_zoom_meeting_2_link?
    generated_link1 = registrant1['join_url'] if registrant1
    generated_link2 = registrant2['join_url'] if registrant2

    # We may need to clear out the existing links and/or keep one the same b/c the other has changed.
    # That's why this conditional is complicated.
    new_join_link1 =  (zoom_meeting_1_configured? ? (generated_link1 || existing_join_link1) : nil)
    new_join_link2 =  (zoom_meeting_2_configured? ? (generated_link2 || existing_join_link2) : nil)

    links_changed = !(existing_join_link1 == new_join_link1 and existing_join_link2 == new_join_link2)
    Honeycomb.add_field('sync_zoom_links_for_participant.changed', links_changed)

    if links_changed
      # Update both links in case we need to clear one out.
      Rails.logger.debug('  - Links changed. Updating Salesforce with new links')
      SalesforceAPI.client.update_zoom_links(@salesforce_participant.id, new_join_link1, new_join_link2)

      # TODO: if the change was because the meeting_id changed or the email changed, a new registrant
      # will be created and the old one will still be in there and working. Need to delete the old
      # one in this scenario so only the new one works. I think we can use the registrantX['registrant_id'
      # field to detect this.
      # https://app.asana.com/0/1201131148207877/1201279111925854
    else
      Rails.logger.debug('  - Skipping Salesforce update. No changes')
    end

    # Save the latest ZoomLinkInfos if we registered them so that we can determine if we need to
    # call into the ZoomAPI to create new links on the next sync or not. Note that we do this regardless
    # of whether or not links_changed in SF. They could be unchanged in the following scenarios and if
    # we didn't save the new info we'd keep calling into the ZoomAPI on every sync (there is a limit of 3
    # per day per registrant):
    # - The ZoomLinkInfo(s) could fail to save. If it was temporary, the next sync would save them. Otherwise,
    #   if there was a bug or bad data it would keep failing which we'd want to see and fix.
    # - The first_name (with prefix) or last_name could change and return the same Zoom link. The name you see
    #   in Zoom gets updated, but the link doesn't change.
    create_or_update_link_infos(registrant1, registrant2)
  end

  def unassign_zoom_links
    Rails.logger.debug("Unassigning Zoom links if necessary for: #{@salesforce_participant.email}")
    cancellation_1 = cancel_registration(@salesforce_participant.zoom_meeting_id_1) if @salesforce_participant.zoom_meeting_link_1
    cancellation_2 = cancel_registration(@salesforce_participant.zoom_meeting_id_2) if @salesforce_participant.zoom_meeting_link_2

    cancellations_happened = (cancellation_1 || cancellation_2)
    Honeycomb.add_field('sync_zoom_links_for_participant.cancelled', cancellations_happened)

    if cancellations_happened
      Rails.logger.debug('  - Registrations cancelled. Updating Salesforce to clear out links')
      SalesforceAPI.client.update_zoom_links(@salesforce_participant.id, nil, nil)
    else
      Rails.logger.debug('  - Skipping Salesforce update. No changes')
    end
  end

  def register_participant(new_zoom_info)
    Rails.logger.debug("  - Generating new #{new_zoom_info.salesforce_meeting_id_attribute} for " +
                       "'#{new_zoom_info.first_name} #{new_zoom_info.last_name}'")
    Honeycomb.add_field("sync_zoom_links_for_participant.generated_new_link.#{new_zoom_info.salesforce_meeting_id_attribute}", true)

    result = ZoomAPI.client.add_registrant(
      new_zoom_info.meeting_id,
      new_zoom_info.email,
      new_zoom_info.first_name_with_prefix,
      new_zoom_info.last_name,
    )
    new_zoom_info.registrant_id = result['registrant_id']
    return result

  rescue ZoomAPI::HostCantRegisterForZoomMeetingError => e
    # This happens normally when staff have Participants, so just skip and don't error out.
    # Set the link to the error message so we store that in Salesforce
    Honeycomb.add_field('zoom.participant.skip_reason', e.message)
    Honeycomb.add_field('zoom.participant.skipped_meeting_id', new_zoom_info.meeting_id)
    Rails.logger.debug(e.message)
    return { 'error' => true, 'join_url' => ZOOM_HOST_LINK_MESSAGE }
  end

  def cancel_registration(meeting_id)
    begin
      if meeting_id.present?
        Rails.logger.debug("  - Cancelling registration for Meeting Id: #{meeting_id}, Email: #{@salesforce_participant.email}")
        # TODO: cutover cancel_registrants to delete_registrant so that a cancellation email doesn't go out.
        # https://app.asana.com/0/1201131148207877/1200865724027633
        ZoomAPI.client.cancel_registrants(meeting_id, [@salesforce_participant.email])
        Honeycomb.add_field('sync_zoom_links_for_participant.registration_cancelled', meeting_id)
      else
        Honeycomb.add_field('zoom.participant.skip_reason', 'Zoom Meeting ID was deleted from Salesforce. Just clear their links.')
      end
    rescue ZoomAPI::ZoomMeetingDoesNotExistError => e
      # If the meeting has been deleted (b/c it's over most likely), just go ahead and say
      # that the registration has been cancelled since the link is useless anyway.
      Honeycomb.add_field('zoom.participant.skip_reason', e.message)
      Rails.logger.debug(e.message)
    end

    return true
  end

  def set_zoom_link_infos
    zoom_link_infos = ZoomLinkInfo.where(salesforce_participant_id: @salesforce_participant.id)

    # The Zoom link info from the last time they were synced
    @existing_zoom_link_info_1 = zoom_link_infos.find_by(salesforce_meeting_id_attribute: :zoom_meeting_id_1)
    Honeycomb.add_field('zoom.participant.link_info_1.existing', @existing_zoom_link_info_1.inspect)
    @existing_zoom_link_info_2 = zoom_link_infos.find_by(salesforce_meeting_id_attribute: :zoom_meeting_id_2)
    Honeycomb.add_field('zoom.participant.link_info_2.existing', @existing_zoom_link_info_2.inspect)

    # The Zoom link info for the current Participant information in Salesforce.
    @new_zoom_link_info_1 = ZoomLinkInfo.parse(@salesforce_participant, :zoom_meeting_id_1)
    Honeycomb.add_field('zoom.participant.link_info_1.new', @new_zoom_link_info_1 .inspect)
    @new_zoom_link_info_2 = ZoomLinkInfo.parse(@salesforce_participant, :zoom_meeting_id_2)
    Honeycomb.add_field('zoom.participant.link_info_2.new', @new_zoom_link_info_2.inspect)
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

  # Is this meeting configured in Salesforce? It is if the Meeting ID is set on the
  # Cohort Schedule, which menas we should be registering participants in the
  # meeting and creating unique links for them to join the meeting
  def zoom_meeting_1_configured?
    @salesforce_participant.zoom_meeting_id_1.present?
  end

  def zoom_meeting_2_configured?
    @salesforce_participant.zoom_meeting_id_2.present?
  end

  def create_or_update_link_infos(registrant1, registrant2)
    upsert_data = []
    upsert_data << @new_zoom_link_info_1.attributes.except('id', 'created_at', 'updated_at') if registrant1 && registrant1['error'].blank?
    upsert_data << @new_zoom_link_info_2.attributes.except('id', 'created_at', 'updated_at') if registrant2 && registrant2['error'].blank?
    if upsert_data.present?
      ZoomLinkInfo.upsert_all(upsert_data, unique_by: [:salesforce_participant_id, :salesforce_meeting_id_attribute])
    end
  end

end
