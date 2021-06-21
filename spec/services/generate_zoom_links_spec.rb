# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateZoomLinks do
  describe '#run' do
    let(:zoom_client) { instance_double(ZoomAPI) }
    let(:meeting_id) { 1234567890 }
    let(:participants) { {} }
    let(:registrants) { build_list :zoom_registrant, participants.count }
    let(:success_response) { double(RestClient::Response) }

    before do
      allow(zoom_client).to receive(:add_registrant).and_return(*registrants)
      allow(ZoomAPI).to receive(:client).and_return(zoom_client)
    end

    subject(:run_generate) do
      GenerateZoomLinks.new(meeting_id: meeting_id, participants: participants).run
    end

    context 'for participants' do
      let(:participants) { build_list(:zoom_participant, 3) }

      it 'calls the Zoom API correctly' do
        expect(zoom_client).to receive(:add_registrant).with(meeting_id, participants[0]).once
        expect(zoom_client).to receive(:add_registrant).with(meeting_id, participants[1]).once
        expect(zoom_client).to receive(:add_registrant).with(meeting_id, participants[2]).once
        run_generate
      end

      it 'returns a CSV with links' do
        csv = CSV.new(run_generate)
        header_row = csv.first
        expect(header_row).to eq(['email', 'first_name', 'last_name', 'join_url'])
        csv.each.with_index(0) do |row, i|
          expected_value = [
            participants[i]['email'],
            participants[i]['first_name'],
            participants[i]['last_name'],
            registrants[i]['join_url']
          ]
          expect(row).to eq(expected_value)
        end
      end
    end

  end # END #run

end
