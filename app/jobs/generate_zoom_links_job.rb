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

#  # TODO: get rid of all the rescue_from() calls in ALL our jobs. Either something changed
#  # or it never worked for Sentry to automatically capture these when raised from here.
#  # I think it's b/c the point of the rescue_from() handler is to handle the error
#  # so that it's not considered a failed job. Just change them all to have a rescue in
#  # the perform method that sends the mail and then re-raises. See above for the pattern to follow
#
#  https://app.asana.com/0/1174274412967132/1200659281191966
#
#  rescue_from(StandardError) do |exception|
#    GenerateZoomLinksMailer.with(email: arguments.second).failure_email.deliver_now
#    raise
#  end
end
