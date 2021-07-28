# frozen_string_literal: true

class GenerateZoomLinksJob < ApplicationJob
  queue_as :default

  def perform(meeting_id, email, participants)
    Honeycomb.add_field('generate_zoom_links.meeting_id', meeting_id)
    Honeycomb.add_field('generate_zoom_links.email', email)
    Honeycomb.add_field('generate_zoom_links.participants', participants)
    Honeycomb.add_field('generate_zoom_links.participants.count', participants.count)
    generate_service = GenerateZoomLinks.new(meeting_id: meeting_id, participants: participants)
    begin
      csv = generate_service.run()
      GenerateZoomLinksMailer.with(email: email, csv: csv).success_email.deliver_now
    rescue => e
      Rails.logger.error(e)
      GenerateZoomLinksMailer.with(
        email: email,
        exception: e,
        participants: participants,
        failed_participants: generate_service.failed_participants
      ).failure_email.deliver_now

      raise
    end
  end
end
