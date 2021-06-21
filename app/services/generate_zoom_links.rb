# frozen_string_literal: true
require 'csv'
require 'zoom_api'

class GenerateZoomLinks

  # @param [Array] participants: each item in the array is a hash with:
  #   { email: 'some-email@email.some', first_name: 'some-name', last_name: 'some-name'}
  def initialize(meeting_id:, participants:)
    @meeting_id = meeting_id
    @participants_to_register = participants
  end

  def run
    registrants = add_registered_participants_to_meeting()
    Honeycomb.add_field('generate_zoom_links.registrants', registrants)
    Honeycomb.add_field('generate_zoom_links.registrants.count', registrants.count)

    # Generate a CSV populated with the join_url so we can email it
    CSV.generate do |csv|
      csv << registrants.first.keys
      registrants.each { |registrant| csv << registrant.values }
    end
  end

private

    def add_registered_participants_to_meeting()
      Rails.logger.info('Started adding participants')

      @participants_to_register.map do |participant|
        response = ZoomAPI.client.add_registrant(@meeting_id, participant)
        participant.merge({ 'join_url' => response['join_url'] })
      end
    end
end
