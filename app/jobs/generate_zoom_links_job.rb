# frozen_string_literal: true

class GenerateZoomLinksJob < ApplicationJob
  queue_as :default

  def perform(meeting_id, email, participants)
    Honeycomb.add_field('generate_zoom_links.meeting_id', meeting_id)
    Honeycomb.add_field('generate_zoom_links.email', email)
    Honeycomb.add_field('generate_zoom_links.participants', participants)
    Honeycomb.add_field('generate_zoom_links.participants.count', participants.count)
    csv = GenerateZoomLinks.new(meeting_id: meeting_id, participants: participants).run
    GenerateZoomLinksMailer.with(email: email, csv: csv).success_email.deliver_now
  end

  rescue_from(StandardError) do |exception|
    GenerateZoomLinksMailer.with(email: arguments.second).failure_email.deliver_now
    raise
  end
end
