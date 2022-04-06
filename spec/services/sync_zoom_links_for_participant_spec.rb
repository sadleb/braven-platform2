# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncZoomLinksForParticipant do
  let(:zoom_client) { double(ZoomAPI) }
  let(:sf_client) { double(SalesforceAPI) }
  let(:force_zoom_update) { false }
  let(:zoom_registrant1) { create :zoom_registrant }
  let(:zoom_registrant2) { create :zoom_registrant }

  # Make sure and set the participant and participant_sync_info_current for each test
  let(:participant) { nil }
  let(:participant_sync_info_current) { nil }

  let(:participant_sync_info) { ParticipantSyncInfo::Diff.new(nil, participant_sync_info_current) }

  before(:each) do
    allow(ZoomAPI).to receive(:client).and_return(zoom_client)
    allow(SalesforceAPI).to receive(:client).and_return(sf_client)
    allow(HerokuConnect::Participant).to receive(:find).and_return(participant)
  end

  describe '#run' do
    subject(:run_sync) do
      SyncZoomLinksForParticipant.new(participant_sync_info, force_zoom_update).run
    end

    shared_examples 'zoom sync' do

      before(:each) do
        participant_sync_info.zoom_meeting_id_1 = meeting_id_1
        participant_sync_info.zoom_meeting_id_2 = meeting_id_2
      end

      shared_examples 'Enrolled Participant' do
        # Make sure and set first_name_prefix variable before calling this

        before(:each) do
          allow(zoom_client).to receive(:add_registrant)
          expect(zoom_client).not_to receive(:cancel_registrants)
          allow(sf_client).to receive(:update_zoom_links)
        end

        shared_examples 'syncs the links' do
          it 'generates links, stores them on the Salesorce Participant records if necessary, and saves the ZoomLinkInfos' do
            generated_link_1 = nil
            generated_link_2 = nil
            if meeting_id_1.present?
              generated_link_1 = zoom_registrant1['join_url']
              expect(zoom_client).to receive(:add_registrant).with(meeting_id_1,
                participant_sync_info.email,
                "#{first_name_prefix}#{participant_sync_info.first_name}",
                participant_sync_info.last_name
              ).and_return(zoom_registrant1).once
            elsif participant_sync_info.zoom_meeting_id_1_changed?
              generated_link_1 = '' # clear out the link in SF
            end

            if meeting_id_2.present?
              generated_link_2 = zoom_registrant2['join_url']
              expect(zoom_client).to receive(:add_registrant).with(meeting_id_2,
                participant_sync_info.email,
                "#{first_name_prefix}#{participant_sync_info.first_name}",
                participant_sync_info.last_name
              ).and_return(zoom_registrant2).once
            elsif participant_sync_info.zoom_meeting_id_2_changed?
              generated_link_2 = '' # clear out the link in SF
            end

            # Even if no meeting IDs are configured, this is still called to clear them out if they had been set previously.
            if !generated_link_1.nil? || !generated_link_2.nil?
              expect(sf_client).to receive(:update_zoom_links).with(participant_sync_info.sfid, generated_link_1, generated_link_2).once
            else
              expect(sf_client).not_to receive(:update_zoom_links)
            end

            zoom_link_info_upsert_data = []
            if generated_link_1.present?
              zoom_link_info1 = ZoomLinkInfo.parse(participant_sync_info, :zoom_meeting_id_1)
              zoom_link_info1.registrant_id = zoom_registrant1['registrant_id']
              zoom_link_info_upsert_data << zoom_link_info1.attributes.except('id', 'created_at', 'updated_at')
            end

            if generated_link_2.present?
              zoom_link_info2 = ZoomLinkInfo.parse(participant_sync_info, :zoom_meeting_id_2)
              zoom_link_info2.registrant_id = zoom_registrant2['registrant_id']
              zoom_link_info_upsert_data << zoom_link_info2.attributes.except('id', 'created_at', 'updated_at')
            end

            if zoom_link_info_upsert_data.present?
              expect(ZoomLinkInfo).to receive(:upsert_all)
                .with(zoom_link_info_upsert_data, {:unique_by=>[:salesforce_participant_id, :salesforce_meeting_id_attribute]})
            end

            run_sync
          end
        end

        context 'on first sync' do
          it_behaves_like 'syncs the links'
        end

        context 'when already synced' do
          before(:each) do
            if meeting_id_1
              zoom_link_info1 = ZoomLinkInfo.parse(participant_sync_info, :zoom_meeting_id_1)
              zoom_link_info1.registrant_id = zoom_registrant1['registrant_id']
              zoom_link_info1.save!
            end

            if meeting_id_2
              zoom_link_info2 = ZoomLinkInfo.parse(participant_sync_info, :zoom_meeting_id_2)
              zoom_link_info2.registrant_id = zoom_registrant2['registrant_id']
              zoom_link_info2.save!
            end
          end

          context 'when no changes' do
            let(:participant_sync_info) { ParticipantSyncInfo::Diff.new(participant_sync_info_current, participant_sync_info_current) }
            it 'skips the sync' do
              expect(zoom_client).not_to receive(:add_registrant)
              expect(sf_client).not_to receive(:update_zoom_links)
              expect(ZoomLinkInfo).not_to receive(:upsert_all)
              run_sync
            end
          end

          context 'when first_name changes' do
            before(:each) do
              ZoomLinkInfo.update_all(first_name: 'OldFirstName')
            end
            it_behaves_like 'syncs the links'
          end

          context 'when last_name changes' do
            before(:each) do
              ZoomLinkInfo.update_all(last_name: 'OldLastName')
            end
            it_behaves_like 'syncs the links'
          end

          context 'when prefix changes' do
            before(:each) do
              ZoomLinkInfo.update_all(prefix: 'OldPrefix')
            end
            it_behaves_like 'syncs the links'
          end

          context 'when email changes' do
            before(:each) do
              ZoomLinkInfo.update_all(email: 'OldEmail@example.com')
            end
            it_behaves_like 'syncs the links'
          end

          context 'when meeting_id changes' do
            before(:each) do
              ZoomLinkInfo.update_all(meeting_id: 'OldMeetingId')
            end
            it_behaves_like 'syncs the links'
          end

          context 'when forced update' do
            let(:force_zoom_update) { true }

            # We already tested the actual link logic above, so these don't both with the actual params sent.
            # Just that the proper methods are called on the APIs and the proper models are stored
            it 'runs the sync' do
              generated_link_1 = nil
              generated_link_2 = nil
              if meeting_id_1.present?
                generated_link_1 = zoom_registrant1['join_url']
                expect(zoom_client).to receive(:add_registrant).with(meeting_id_1, anything, anything, anything).and_return(zoom_registrant1).once
              elsif participant_sync_info.zoom_meeting_id_1_changed?
                generated_link_1 = ''
              end

              if meeting_id_2.present?
                generated_link_2 = zoom_registrant2['join_url']
                expect(zoom_client).to receive(:add_registrant).with(meeting_id_2, anything, anything, anything).and_return(zoom_registrant2).once
              elsif participant_sync_info.zoom_meeting_id_2_changed?
                generated_link_2 = ''
              end

              if !generated_link_1.nil? || !generated_link_2.nil?
                expect(sf_client).to receive(:update_zoom_links).with(participant_sync_info.sfid, generated_link_1, generated_link_2).once
              else
                expect(sf_client).not_to receive(:update_zoom_links)
              end

              if generated_link_1.present? || generated_link_2.present?
                expect(ZoomLinkInfo).to receive(:upsert_all)
              else
                expect(ZoomLinkInfo).not_to receive(:upsert_all)
              end

              run_sync
            end
          end
        end

        # Make sure that this particular error is not treated as a sync failure. Staff members that are hosts
        # of the Zoom meeting can be sync'd to the Course as a Teaching Assistant (or some other staff role).
        # Instead of a real link, just return a message about why the Zoom link wasn't created so people know what's up.
        context 'when syncing Host of Zoom meeting' do
          let(:error_message) { 'We cannot create a pre-registered Zoom link for a host.' }

          it 'returns a message about why the link wasnt created as the link itself so that staff knows what is going on' do
            generated_link_1 = nil
            generated_link_2 = nil

            if meeting_id_1.present?
              generated_link_1 = SyncZoomLinksForParticipant::ZOOM_HOST_LINK_MESSAGE
              allow(zoom_client).to receive(:add_registrant).with(meeting_id_1,
                participant_sync_info.email,
                "#{first_name_prefix}#{participant_sync_info.first_name}",
                participant_sync_info.last_name
              ).and_raise(ZoomAPI::HostCantRegisterForZoomMeetingError, error_message)
            elsif participant_sync_info.zoom_meeting_id_1_changed?
              generated_link_1 = ''
            end

            if meeting_id_2.present?
              generated_link_2 = SyncZoomLinksForParticipant::ZOOM_HOST_LINK_MESSAGE
              allow(zoom_client).to receive(:add_registrant).with(meeting_id_2,
                participant_sync_info.email,
                "#{first_name_prefix}#{participant_sync_info.first_name}",
                participant_sync_info.last_name
              ).and_raise(ZoomAPI::HostCantRegisterForZoomMeetingError, error_message)
            elsif participant_sync_info.zoom_meeting_id_2_changed?
              generated_link_2 = ''
            end

            # Even if no meeting IDs are configured, this is still called to clear them out if they had been set previously.
            if !generated_link_1.nil? || !generated_link_2.nil?
              expect(sf_client).to receive(:update_zoom_links).with(participant_sync_info.sfid, generated_link_1, generated_link_2).once
            else
              expect(sf_client).not_to receive(:update_zoom_links)
            end

            expect(ZoomLinkInfo).not_to receive(:upsert_all)

            run_sync
          end
        end

      end # END 'Enrolled Participant' examples

      context 'Fellow' do
        let(:participant) { build :heroku_connect_fellow_participant }
        let(:participant_sync_info_current) { create :participant_sync_info_fellow, participant: participant }
        let(:first_name_prefix) { ZoomLinkInfo.calculate_zoom_prefix(participant_sync_info_current) }
        it_behaves_like 'Enrolled Participant'
      end

      context 'Leadership Coach' do
        let(:participant) { build :heroku_connect_lc_participant }
        let(:participant_sync_info_current) { create :participant_sync_info_lc, participant: participant }
        let(:first_name_prefix) { 'LC - ' }
        it_behaves_like 'Enrolled Participant'
      end

      context 'Coach Partner' do
        let(:participant) { build :heroku_connect_cp_participant }
        let(:participant_sync_info_current) { create :participant_sync_info_cp, participant: participant }
        let(:first_name_prefix) { 'CP - ' }
        it_behaves_like 'Enrolled Participant'
      end

      context 'Teaching Assistant' do
        let(:participant) { build :heroku_connect_ta_participant }
        let(:participant_sync_info_current) { create :participant_sync_info_ta, participant: participant }
        let(:first_name_prefix) { 'TA - ' }
        it_behaves_like 'Enrolled Participant'
      end

      context 'Staff' do
        let(:participant) { build :heroku_connect_staff_participant }
        let(:participant_sync_info_current) { create :participant_sync_info_staff, participant: participant }
        let(:first_name_prefix) { 'Staff - ' }
        it_behaves_like 'Enrolled Participant'
      end

      context 'Faculty' do
        let(:participant) { build :heroku_connect_faculty_participant }
        let(:participant_sync_info_current) { create :participant_sync_info_faculty, participant: participant }
        let(:first_name_prefix) { 'Faculty - ' }
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
          it 'skips the sync' do
            expect(sf_client).not_to receive(:update_zoom_links)
            expect(sf_client).not_to receive(:cancel_registrants)
            expect { run_sync }.not_to change(ZoomLinkInfo, :count)
          end
        end

        context 'with one existing link' do
          let(:existing_zoom_link_info) {
            participant_sync_info.zoom_meeting_id_1 = 'old_meeting_id'
            zli = ZoomLinkInfo.parse(participant_sync_info, :zoom_meeting_id_1)
            zli.registrant_id = zoom_registrant1['registrant_id']
            zli.save!
            zli
          }

          it 'cancels only that registration and clears the links from their Salesforce Participant record' do
            expect(zoom_client).to receive(:cancel_registrants)
              .with(existing_zoom_link_info.meeting_id, [participant_sync_info.email])
              .and_return(no_content_response).once

            if meeting_id_1.present?
              expect(zoom_client).not_to receive(:cancel_registrants)
                .with(meeting_id_1, anything)
            end

            if meeting_id_2.present?
              expect(zoom_client).not_to receive(:cancel_registrants)
                .with(meeting_id_2, anything)
            end

            expect(sf_client).to receive(:update_zoom_links).with(participant_sync_info.sfid, '', '')

            expect { run_sync }.to change(ZoomLinkInfo, :count).by(-1)
          end
        end

        context 'with both existing links' do
          let(:existing_zoom_link_info1) {
            participant_sync_info.zoom_meeting_id_1 = 'old_meeting_id1'
            zli1 = ZoomLinkInfo.parse(participant_sync_info, :zoom_meeting_id_1)
            zli1.registrant_id = zoom_registrant1['registrant_id']
            zli1.save!
            zli1
          }
          let(:existing_zoom_link_info2) {
            participant_sync_info.zoom_meeting_id_2 = 'old_meeting_id2'
            zli2 = ZoomLinkInfo.parse(participant_sync_info, :zoom_meeting_id_2)
            zli2.registrant_id = zoom_registrant2['registrant_id']
            zli2.save!
            zli2
          }

          it 'cancels both registrations and clears the links from their Salesforce Participant record' do
            expect(zoom_client).to receive(:cancel_registrants)
              .with(existing_zoom_link_info1.meeting_id, [participant_sync_info.email])
              .and_return(no_content_response).once
            expect(zoom_client).to receive(:cancel_registrants)
              .with(existing_zoom_link_info2.meeting_id, [participant_sync_info.email])
              .and_return(no_content_response).once

            if meeting_id_1.present?
              expect(zoom_client).not_to receive(:cancel_registrants)
                .with(meeting_id_2, anything)
            end

            if meeting_id_2.present?
              expect(zoom_client).not_to receive(:cancel_registrants)
                .with(meeting_id_2, anything)
            end

            expect(sf_client).to receive(:update_zoom_links).with(participant_sync_info.sfid, '', '')

            expect { run_sync }.to change(ZoomLinkInfo, :count).by(-2)
          end

          # Make sure that this particular error is not treated as a sync failure. No need to cancel the registration
          # of a non-existent meeting.
          context 'when Zoom meeting deleted' do
            it 'still deletes the links from Salesforce and ignores the ZoomAPI error' do
              expect(zoom_client).to receive(:cancel_registrants)
                .with(existing_zoom_link_info1.meeting_id, [participant_sync_info.email])
                .and_raise(ZoomAPI::ZoomMeetingDoesNotExistError, 'We cannot cancel the Zoom registration for email(s)')

              expect(sf_client).to receive(:update_zoom_links).with(participant_sync_info.sfid, '', '').once

              run_sync
            end
          end
        end
      end # END 'Dropped Participants'

      context 'Dropped Fellow' do
        let(:participant) { build :heroku_connect_fellow_participant, status__c: HerokuConnect::Participant::Status::DROPPED }
        let(:participant_sync_info_current) { create :participant_sync_info_fellow, participant: participant}
        it_behaves_like 'Dropped Participant'
      end

      context 'Dropped Leadership Coach' do
        let(:participant) { build :heroku_connect_lc_participant, status__c: HerokuConnect::Participant::Status::DROPPED }
        let(:participant_sync_info_current) { create :participant_sync_info_lc, participant: participant }
        it_behaves_like 'Dropped Participant'
      end

      context 'Dropped Coach Partner' do
        let(:participant) { build :heroku_connect_cp_participant, status__c: HerokuConnect::Participant::Status::DROPPED }
        let(:participant_sync_info_current) { create :participant_sync_info_cp, participant: participant }
        it_behaves_like 'Dropped Participant'
      end
    end # END 'zoom sync' examples

    context 'with no meetings configured' do
      let(:meeting_id_1) { nil }
      let(:meeting_id_2) { nil }
      it_behaves_like 'zoom sync'
    end

    context 'with meeting 1 configured' do
      let(:meeting_id_1) { '1234567890' }
      let(:meeting_id_2) { nil }
      it_behaves_like 'zoom sync'
    end

    context 'with both meetings configured' do
      let(:meeting_id_1) { '1234567890' }
      let(:meeting_id_2) { '9876543210' }
      it_behaves_like 'zoom sync'
    end

    context 'with duplicate registrant_id for participant that violates the ZoomLinkInfo unique constraint' do
      let(:participant) { build :heroku_connect_fellow_participant }
      let(:participant_sync_info_current) { create :participant_sync_info_fellow, participant: participant }
      let(:meeting_id_1) { '1234567890' }
      let(:meeting_id_2) { nil }
      let(:zoom_registrant2) { nil }
      let!(:zoom_link_info1) { create(
        :zoom_link_info,
        registrant_id: zoom_registrant1['id']
      )}

      before(:each) do
        allow(zoom_client)
          .to receive(:add_registrant)
          .and_return(zoom_registrant1)
        allow(sf_client).to receive(:update_zoom_links)
        participant_sync_info.zoom_meeting_id_2 = meeting_id_2
      end

      it 'removes ZoomLinkInfo where registrant_id is a duplicate' do
        zoom_info_arr = ZoomLinkInfo.where(id: zoom_link_info1.id)

        expect(zoom_info_arr.count).not_to eq(0)
        subject
        expect(zoom_info_arr.reload.count).to eq(0)
      end
    end
  end # END '#run'

end
