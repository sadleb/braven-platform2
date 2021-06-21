# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncZoomLinksForParticipant do
  let(:zoom_client) { double(ZoomAPI) }
  let(:sf_client) { double(SalesforceAPI) }
  # Make sure and set the salesforce_participant for each test
  let(:salesforce_participant_struct) { SalesforceAPI.participant_to_struct(salesforce_participant) }
  let(:force_zoom_update) { false }
  let(:zoom_registrant1) { create :zoom_registrant }
  let(:zoom_registrant2) { create :zoom_registrant }

  before(:each) do
    allow(ZoomAPI).to receive(:client).and_return(zoom_client)
    allow(SalesforceAPI).to receive(:client).and_return(sf_client)
  end

  describe '#run' do
    subject(:run_sync) do
      SyncZoomLinksForParticipant.new(salesforce_participant_struct, force_zoom_update).run
    end

    shared_examples 'zoom sync' do

      before(:each) do
        salesforce_participant_struct.zoom_meeting_id_1 = meeting_id_1
        salesforce_participant_struct.zoom_meeting_id_2 = meeting_id_2
        salesforce_participant_struct.zoom_meeting_link_1 = meeting_link_1
        salesforce_participant_struct.zoom_meeting_link_2 = meeting_link_2
      end

      shared_examples 'Enrolled Participant' do
        # Make sure and set first_name_prefix variable before calling this

        before(:each) do
          allow(zoom_client).to receive(:add_registrant)
          expect(zoom_client).not_to receive(:cancel_registrants)
          allow(sf_client).to receive(:update_zoom_links)
        end

        context 'on first sync' do
          let(:meeting_link_1) { nil }
          let(:meeting_link_2) { nil }

          it 'generates links and stores them on the Salesorce Participant records if necessary' do
            join_url1 = nil
            join_url2 = nil
            if meeting_id_1.present?
              join_url1 = zoom_registrant1['join_url']
              expect(zoom_client).to receive(:add_registrant).with(meeting_id_1, {
                'email' => salesforce_participant_struct.email,
                'first_name' => "#{first_name_prefix}#{salesforce_participant_struct.first_name}",
                'last_name' => salesforce_participant_struct.last_name
              }).and_return(zoom_registrant1).once
            end

            if meeting_id_2.present?
              join_url2 = zoom_registrant2['join_url']
              expect(zoom_client).to receive(:add_registrant).with(meeting_id_2, {
                'email' => salesforce_participant_struct.email,
                'first_name' => "#{first_name_prefix}#{salesforce_participant_struct.first_name}",
                'last_name' => salesforce_participant_struct.last_name
              }).and_return(zoom_registrant2).once
            end

            # Even if no meeting IDs are configured, this is still called to clear them out if they had been set previously.
            if join_url1 != salesforce_participant_struct.zoom_meeting_link_1 ||
               join_url2 != salesforce_participant_struct.zoom_meeting_link_2
              expect(sf_client).to receive(:update_zoom_links).with(salesforce_participant_struct.id, join_url1, join_url2).once
            end

            run_sync
          end
        end

        context 'when already synced' do
          let(:meeting_link_1) { zoom_registrant1['join_url'] if meeting_id_1 }
          let(:meeting_link_2) { zoom_registrant2['join_url'] if meeting_id_2 }

          it 'skips the sync' do
            expect(zoom_client).not_to receive(:add_registrant)
            expect(sf_client).not_to receive(:update_zoom_links)
            run_sync
          end

          context 'when forced update' do
            let(:meeting_link_1) { 'https://fake.old.zoom.link1.com' }
            let(:meeting_link_2) { 'https://fake.old.zoom.link2.com' }
            let(:force_zoom_update) { true }

            # We already tested the actual link logic above, so these don't both with the actual params sent.
            # Just that the proper methods are called on the APIs
            it 'runs the sync' do
              join_url1 = nil
              join_url2 = nil
              if meeting_id_1.present?
                join_url1 = zoom_registrant1['join_url']
                expect(zoom_client).to receive(:add_registrant).with(meeting_id_1, anything).and_return(zoom_registrant1).once
              end

              if meeting_id_2.present?
                join_url2 = zoom_registrant2['join_url']
                expect(zoom_client).to receive(:add_registrant).with(meeting_id_2, anything).and_return(zoom_registrant2).once
              end

              if join_url1 != salesforce_participant_struct.zoom_meeting_link_1 ||
                 join_url2 != salesforce_participant_struct.zoom_meeting_link_2
                expect(sf_client).to receive(:update_zoom_links).with(salesforce_participant_struct.id, join_url1, join_url2).once
              end

              run_sync
            end
          end
        end
      end # END 'Enrolled Participant' examples

      context 'Fellow' do
        let(:salesforce_participant) { create :salesforce_participant_fellow }
        let(:first_name_prefix) { "#{salesforce_participant_struct.zoom_prefix} - " }
        it_behaves_like 'Enrolled Participant'
      end

      context 'Leadership Coach' do
        let(:salesforce_participant) { create :salesforce_participant_lc }
        let(:first_name_prefix) { 'LC - ' }
        it_behaves_like 'Enrolled Participant'
      end

      context 'Coach Partner' do
        let(:salesforce_participant) { create :salesforce_participant_cp }
        let(:first_name_prefix) { 'CP - ' }
        it_behaves_like 'Enrolled Participant'
      end

      shared_examples 'Dropped Participant' do
        let(:no_content_response) { double(RestClient::Response, :code => 204) }

        before(:each) do
          allow(zoom_client).to receive(:cancel_registrants)
          expect(zoom_client).not_to receive(:add_registrant)
          allow(sf_client).to receive(:update_zoom_links)
        end

        context 'without existing links' do
          let(:meeting_link_1) { nil }
          let(:meeting_link_2) { nil }

          it 'skips the sync' do
            expect(sf_client).not_to receive(:update_zoom_links)
            expect(sf_client).not_to receive(:cancel_registrants)
            run_sync
          end
        end

        context 'with one existing link' do
          let(:meeting_link_1) { zoom_registrant1['join_url'] }
          let(:meeting_link_2) { nil }

          it 'cancels only that registration and clears the links from their Salesforce Participant record' do
            expect(zoom_client).to receive(:cancel_registrants)
              .with(meeting_id_1, [salesforce_participant_struct.email])
              .and_return(no_content_response).once

            expect(zoom_client).not_to receive(:cancel_registrants)
              .with(meeting_id_2, anything)

            expect(sf_client).to receive(:update_zoom_links).with(salesforce_participant_struct.id, nil, nil)

            run_sync
          end
        end

        context 'with both existing links' do
          let(:meeting_link_1) { zoom_registrant1['join_url'] }
          let(:meeting_link_2) { zoom_registrant2['join_url'] }

          it 'cancels both registrations and clears the links from their Salesforce Participant record' do
            expect(zoom_client).to receive(:cancel_registrants)
              .with(meeting_id_1, [salesforce_participant_struct.email])
              .and_return(no_content_response).once

            expect(zoom_client).to receive(:cancel_registrants)
              .with(meeting_id_2, [salesforce_participant_struct.email])
              .and_return(no_content_response).once

            expect(sf_client).to receive(:update_zoom_links).with(salesforce_participant_struct.id, nil, nil)

            run_sync
          end
        end

      end # END 'Dropped Participants'

      context 'Dropped Fellow' do
        let(:salesforce_participant) { create :salesforce_participant_fellow, :ParticipantStatus => SalesforceAPI::DROPPED }
        it_behaves_like 'Dropped Participant'
      end

      context 'Dropped Leadership Coach' do
        let(:salesforce_participant) { create :salesforce_participant_lc, :ParticipantStatus => SalesforceAPI::DROPPED }
        it_behaves_like 'Dropped Participant'
      end

      context 'Dropped Coach Partner' do
        let(:salesforce_participant) { create :salesforce_participant_cp, :ParticipantStatus => SalesforceAPI::DROPPED }
        it_behaves_like 'Dropped Participant'
      end
    end # END 'zoom sync' examples

    context 'with no meetings configured' do
      let(:meeting_id_1) { nil }
      let(:meeting_id_2) { nil }
      it_behaves_like 'zoom sync'
    end

    context 'with meeting 1 configured' do
      let(:meeting_id_1) { 1234567890 }
      let(:meeting_id_2) { nil }
      it_behaves_like 'zoom sync'
    end

    context 'with both meetings configured' do
      let(:meeting_id_1) { 1234567890 }
      let(:meeting_id_2) { 9876543210 }
      it_behaves_like 'zoom sync'
    end

  end # END '#run'

end
