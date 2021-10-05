# frozen_string_literal: true
require 'salesforce_api'
require 'zoom_api'

class SyncZoomLinksForParticipant

  ZOOM_HOST_LINK_MESSAGE = 'NONE: cannot generate Zoom link for a Host of the meeting'

  def initialize(salesforce_participant, force_update = false)
    @salesforce_participant = salesforce_participant
    @force_update = force_update
  end

  def run
    Honeycomb.start_span(name: 'sync_zoom_links_for_participant.run') do |span|
      add_honeycomb_participant_fields
      assign_zoom_links if @salesforce_participant.status == SalesforceAPI::ENROLLED
      unassign_zoom_links unless @salesforce_participant.status == SalesforceAPI::ENROLLED
    end
  end

private

  def assign_zoom_links
    Rails.logger.debug("Assigning Zoom links if necessary for: #{@salesforce_participant.email}")

    prefix = compute_prefix
    first_name = @salesforce_participant.first_name
    first_name = prefix + first_name if prefix

    @registration_details = {
      'email' => @salesforce_participant.email,
      'first_name' => first_name,
      'last_name' => @salesforce_participant.last_name
    }

    old_join_link1 = @salesforce_participant.zoom_meeting_link_1
    old_join_link2 = @salesforce_participant.zoom_meeting_link_2

    generated_link1 = generate_meeting_link(@salesforce_participant.zoom_meeting_id_1, 1) if generate_zoom_meeting_1_link?
    generated_link2 = generate_meeting_link(@salesforce_participant.zoom_meeting_id_2, 2) if generate_zoom_meeting_2_link?

    new_join_link1 =  (zoom_meeting_1_configured? ? (generated_link1 || old_join_link1) : nil)
    new_join_link2 =  (zoom_meeting_2_configured? ? (generated_link2 || old_join_link2) : nil)

    links_changed = !(old_join_link1 == new_join_link1 and old_join_link2 == new_join_link2)
    Honeycomb.add_field('sync_zoom_links_for_participant.changed', links_changed)

    if links_changed
      # Update both links in case we need to clear one out.
      Rails.logger.debug('  - Links changed. Updating Salesforce with new links')
      SalesforceAPI.client.update_zoom_links(@salesforce_participant.id, new_join_link1, new_join_link2)
    else
      Rails.logger.debug('  - Skipping Salesforce update. No changes')
    end
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

  def generate_meeting_link(meeting_id, link_number)
    first_name = @registration_details['first_name']
    last_name = @registration_details['last_name']
    Rails.logger.debug("  - Generating link #{link_number} for '#{first_name} #{last_name}'")
    Honeycomb.add_field("sync_zoom_links_for_participant.generate_link_#{link_number}", true)
    Honeycomb.add_field('zoom.participant.first_name', first_name) # Send this so we can query by name prefixes used for breakout rooms
    Honeycomb.add_field('zoom.participant.last_name', last_name)

    return ZoomAPI.client.add_registrant(meeting_id, @registration_details)['join_url']

  rescue ZoomAPI::HostCantRegisterForZoomMeetingError => e
    Honeycomb.add_field('zoom.participant.skip_reason', e.message)
    Rails.logger.debug(e.message)
    return ZOOM_HOST_LINK_MESSAGE
  end

  def cancel_registration(meeting_id)
    begin
      if meeting_id.present?
        Rails.logger.debug("  - Cancelling registration for Meeting Id: #{meeting_id}, Email: #{@salesforce_participant.email}")
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

  # We prefix their first names to help with managing breakout rooms. Regional folks need to be
  # able to easily see which Fellows and LCs are in a Cohort so they can put them together in a
  # breakout room. CPs float around and are manually managed in an-hoc manner. We just need to
  # know that they are a CP.
  def compute_prefix
    return 'TA - ' if @salesforce_participant.role == SalesforceAPI::TEACHING_ASSISTANT
    return 'CP - ' if SalesforceAPI.is_coach_partner?(@salesforce_participant)
    return 'LC - ' if SalesforceAPI.is_lc?(@salesforce_participant)

    # For all other types (aka Fellows), use Zoom prefix from the Cohort. This is as formula
    # on the Salesforce side that for now just uses FirstName LastInitial (e.g. 'Brian S'),
    # but may eventually be a different format for co-LCs, like 'LCName1 & LCName 2'
    # If no Cohort is assigned, it will just be an empty string since we have no info to help
    # with breakout rooms.
    return "#{@salesforce_participant.zoom_prefix} - " if @salesforce_participant.zoom_prefix.present?

    return ''
  end

  # Note that a force_update doesn't actually update the link unless other info has changed,
  # like the password for the meeting for example.
  def generate_zoom_meeting_1_link?
    zoom_meeting_1_configured? && (
      @force_update || @salesforce_participant.zoom_meeting_link_1.blank?
    )
  end

  def generate_zoom_meeting_2_link?
    zoom_meeting_2_configured? && (
      @force_update || @salesforce_participant.zoom_meeting_link_2.blank?
    )
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

  def add_honeycomb_participant_fields
    Honeycomb.add_field('salesforce.contact.email', @salesforce_participant.email)
    Honeycomb.add_field('salesforce.participant.id', @salesforce_participant.id)
    Honeycomb.add_field('salesforce.participant.status', @salesforce_participant.status)
    Honeycomb.add_field('salesforce.participant.zoom_meeting_id_1', @salesforce_participant.zoom_meeting_id_1)
    Honeycomb.add_field('salesforce.participant.zoom_meeting_id_2', @salesforce_participant.zoom_meeting_id_2)
  end

end
