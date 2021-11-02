# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateZoomLinks do
  describe '#run' do
    let(:zoom_client) { instance_double(ZoomAPI) }
    let(:meeting_id) { '1234567890' }
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
        expect(zoom_client).to receive(:add_registrant).with(meeting_id, *participants[0].values).once
        expect(zoom_client).to receive(:add_registrant).with(meeting_id, *participants[1].values).once
        expect(zoom_client).to receive(:add_registrant).with(meeting_id, *participants[2].values).once
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

      context 'for Meeting ID with whitespace' do
        let(:meeting_id) { '123 456 7890 ' }
        let(:meeting_id_no_whitespace) { '1234567890' }

        it 'removes whitespace' do
          expect(zoom_client).to receive(:add_registrant).with(meeting_id_no_whitespace, *participants[0].values).once
          expect(zoom_client).to receive(:add_registrant).with(meeting_id_no_whitespace, *participants[1].values).once
          expect(zoom_client).to receive(:add_registrant).with(meeting_id_no_whitespace, *participants[2].values).once
          run_generate
        end
      end

      context 'for invalid Meeting ID' do
        # They must be 10 or 11 digits. See:
        # https://support.zoom.us/hc/en-us/articles/201362373-Meeting-and-Webinar-IDs#:~:text=The%20meeting%20ID%20can%20be,may%20be%209%2Ddigits%20long.
        let(:meeting_id) { '123456789' }

        it 'throws an error' do
          expect{ run_generate }.to raise_error(GenerateZoomLinks::GenerateZoomLinksError, "Meeting ID '#{meeting_id}' format is invalid. It must be a 10 or 11 digit number.")
        end
      end
    end

  end # END #run

end
