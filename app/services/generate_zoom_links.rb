# frozen_string_literal: true
require 'csv'
require 'zoom_api'

class GenerateZoomLinks
  attr_reader :failed_participants

  class GenerateZoomLinksError < StandardError; end

  # @param [Array] participants: each item in the array is a hash with:
  #   { email: 'some-email@email.some', first_name: 'some-name', last_name: 'some-name'}
  def initialize(meeting_id:, participants:)
    @meeting_id = meeting_id.delete_whitespace
    @participants_to_register = participants
    @failed_participants = []
  end

  def run
    Honeycomb.add_field('generate_zoom_links.participants', @participants_to_register)
    Honeycomb.add_field('generate_zoom_links.participants.count', @participants_to_register.count)

    validate_meeting(@meeting_id)

    registered_participants = add_registered_participants_to_meeting()

    unless @failed_participants.empty?
      Rails.logger.error(@failed_participants.inspect)
      Honeycomb.add_field('alert.generate_zoom_links.failed_participants', @failed_participants)
      raise GenerateZoomLinksError, "Failed to generate Zoom links. The following participants failed => #{@failed_participants.inspect}"
    end

    # Generate a CSV populated with the join_url so we can email it
    CSV.generate do |csv|
      csv << registered_participants.first.keys
      registered_participants.each { |participant| csv << participant.values }
    end
  end

private

  def add_registered_participants_to_meeting()
    Rails.logger.info('Started adding participants')

    @participants_to_register.map.with_index do |participant, i|
      csv_row_with_link = nil
      begin
        response = ZoomAPI.client.add_registrant(@meeting_id, participant)
        csv_row_with_link = participant.merge({ 'join_url' => response['join_url'] })
      rescue => e
        Sentry.capture_exception(e)
        # Add 2 to get the .csv row # b/c we don't parse the header row and need to make it 1 based instead of 0 based.
        row = i+2
        @failed_participants << participant.merge({'row_number' => row, 'error_detail' => "#{e.class}: #{e.message}" })
      end
      csv_row_with_link
    end.compact
  end

  def validate_meeting(meeting_id)
    unless /^\d{10,11}$/.match(meeting_id)
      raise GenerateZoomLinksError, "Meeting ID '#{meeting_id}' format is invalid. It must be a 10 or 11 digit number."
    end

    # TODO: use API calls to make sure the meeting is set up properly.
    # E.g. that "Registration = required" is turned on, email notifications are off, etc.
    # https://app.asana.com/0/1174274412967132/1200659281191965
  end
end
