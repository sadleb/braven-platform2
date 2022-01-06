# since it's a bot. frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncSalesforceProgram do
# TODO: reimplement specs after this refactoring: https://github.com/bebraven/platform/pull/922
# https://app.asana.com/0/1201131148207877/1201399664994348

#  let!(:fellow_course) { create :course_launched, canvas_course_id: sf_program_struct.fellow_course_id }
#  let(:fellow_canvas_course_id) { fellow_course.canvas_course_id }
#  let(:sf_participants) { [] }
#  let(:sf_program_struct) { SalesforceAPI.program_to_struct(create(:salesforce_program_record)) }
#  let(:lms_client) { double(CanvasAPI, find_user_by: nil) }
#  let(:sf_client) { double(SalesforceAPI, update_contact: nil, find_program: sf_program_struct) }
#  let(:sync_account_service) { double(SyncSalesforceParticipant, run: nil) }
#  let(:sync_zoom_service) { double(SyncZoomLinksForParticipant, run: nil) }
#
#  before(:each) do
#    allow(SyncSalesforceParticipant).to receive(:new).and_return(sync_account_service)
#    allow(SyncZoomLinksForParticipant).to receive(:new).and_return(sync_zoom_service)
#    allow(SalesforceAPI).to receive(:client).and_return(sf_client)
#    allow(CanvasAPI).to receive(:client).and_return(lms_client)
#  end
#
#  describe '#run' do
#    before(:each) do
#      allow(sf_client).to receive(:find_participants_by).with(program_id: sf_program_struct.id).and_return(sf_participants)
#    end
#
#    context 'with missing Course model' do
#      # make the canvas_course_id not match the program
#      let!(:fellow_course) { create :course_launched, canvas_course_id: sf_program_struct.fellow_course_id + 1 }
#
#      it 'raises an error' do
#        expect{ SyncSalesforceProgram.new(salesforce_program_id: sf_program_struct.id).run }
#          .to raise_error(SyncSalesforceProgram::SyncSalesforceProgramError, /Missing Course/)
#      end
#    end
#
#    describe '#sync_program_id' do
#      subject(:run_sync) do
#        SyncSalesforceProgram.new(salesforce_program_id: sf_program_struct.id).run
#      end
#
#      context 'when Program Id out of sync with Course model' do
#        it 'updates the models' do
#          mismatched_program_id = sf_program_struct.id.reverse
#          fellow_course.update!(salesforce_program_id: mismatched_program_id)
#          expect{ run_sync }.to change{ fellow_course.reload.salesforce_program_id}
#            .from(mismatched_program_id).to(sf_program_struct.id)
#        end
#
#        it 'clears the mistmatched models' do
#          mismatched_program_id = sf_program_struct.id.reverse
#          fellow_course.update!(salesforce_program_id: mismatched_program_id)
#          old_fellow_course = create(:course_launched,
#            canvas_course_id: fellow_course.canvas_course_id + 1, salesforce_program_id: sf_program_struct.id
#          )
#          expect{ run_sync }.to change{ old_fellow_course.reload.salesforce_program_id}
#            .from(sf_program_struct.id).to(nil)
#        end
#      end
#
#      context 'when Program Id matches' do
#        let!(:fellow_course) { create :course_launched,
#          canvas_course_id: sf_program_struct.fellow_course_id,
#          salesforce_program_id: sf_program_struct.id
#        }
#
#        it 'is a NOOP' do
#          expect(fellow_course.salesforce_program_id).to eq(sf_program_struct.id)
#          expect{ run_sync }.not_to change{ fellow_course.reload.salesforce_program_id }
#        end
#      end
#    end
#
#    # These are Participants where we are running Sync From Salesforce for the first time since they
#    # were added to the Program. We create a new User record. The primary motivation for this
#    # is so that we can allow them to use the password reset flow to sign up and create an
#    # account if they lost, can't find, or don't think to look for their welcome email asking
#    # them to create an account.
#    context 'with new participants' do
#      let(:new_sf_participant) { create :salesforce_participant, program_id: sf_program_struct.id }
#      let(:new_sf_participant_struct) { SalesforceAPI.participant_to_struct(new_sf_participant) }
#      let(:sf_participants) { [new_sf_participant_struct] }
#      let(:new_user) { double(User).as_null_object }
#
#      before(:each) do
#        allow(new_user).to receive(:blank?).and_return(false)
#        allow(User).to receive(:new).and_return(new_user)
#      end
#
#      subject(:run_sync) do
#        SyncSalesforceProgram.new(salesforce_program_id: sf_program_struct.id).run
#      end
#
#      it 'creates a new User record' do
#        expect(new_user).to receive(:save!).once
#        run_sync
#      end
#
#      context 'when Participant.Status equals Dropped' do
#        let(:new_sf_participant) { create :salesforce_participant, :ParticipantStatus => SalesforceAPI::DROPPED }
#        it 'does not create a new User record' do
#          expect(User).not_to receive(:new)
#          run_sync
#        end
#
#        it 'does not create Zoom links' do
#          expect(sync_zoom_service).not_to receive(:run)
#          run_sync
#        end
#
#        it 'does not enroll in Canvas' do
#          expect(sync_account_service).not_to receive(:run)
#          run_sync
#        end
#      end
#
#      it 'doesnt send a confirmation email' do
#        expect(new_user).to receive(:skip_confirmation_notification!).once
#        run_sync
#      end
#
#      it 'generates signup token' do
#        allow(new_user).to receive(:signup_token).and_return(nil)
#        expect(new_user).to receive(:set_signup_token!).once
#        run_sync
#      end
#
#      it 'sends the signup token and user.id to Salesforce' do
#        fake_token = 'fake_token'
#        allow(new_user).to receive(:set_signup_token!).and_return(fake_token)
#        salesforce_contact_fields_to_set = {
#          'Platform_User_ID__c': new_user.id,
#          'Signup_Token__c': fake_token,
#        }
#        expect(sf_client).to receive(:update_contact).with(new_user.salesforce_id, salesforce_contact_fields_to_set).once
#        run_sync
#      end
#
#      it 'runs the Zoom sync service' do
#        force_zoom_updates = false
#        expect(SyncZoomLinksForParticipant).to receive(:new).with(new_sf_participant_struct, force_zoom_updates).once
#        expect(sync_zoom_service).to receive(:run).once
#        run_sync
#      end
#    end
#
#    context 'with failed participants' do
#      let(:user_success) { create :registered_user }
#      let(:portal_user_success) { CanvasAPI::LMSUser.new(user_success.canvas_user_id, user_success.email) }
#      let(:sf_participant_success) {
#        sf_part_hash = create :salesforce_participant,
#          :ContactId => user_success.salesforce_id,
#          :FirstName => user_success.first_name,
#          :LastName => user_success.last_name,
#          :Email => user_success.email
#        SalesforceAPI.participant_to_struct(sf_part_hash)
#      }
#      let(:user_fail) { create :registered_user }
#      let(:portal_user_fail) { CanvasAPI::LMSUser.new(user_fail.canvas_user_id, user_fail.email) }
#      let(:sf_participant_fail) {
#        sf_part_hash = create :salesforce_participant,
#          :ContactId => user_fail.salesforce_id,
#          :FirstName => user_fail.first_name,
#          :LastName => user_fail.last_name,
#          :Email => user_fail.email
#        SalesforceAPI.participant_to_struct(sf_part_hash)
#      }
#      # Note the order here matters. fail first, then success
#      let(:sf_participants) { [sf_participant_fail, sf_participant_success] }
#      let(:sync_program_service) { SyncSalesforceProgram.new(salesforce_program_id: sf_program_struct.id) }
#
#      context 'for general failure' do
#        before(:each) do
#          expect(lms_client).to receive(:find_user_by).with(email: sf_participant_fail.email, salesforce_contact_id: anything, platform_user_id: anything)
#            .and_raise("Fake Exception")
#          expect(lms_client).to receive(:find_user_by).with(email: sf_participant_success.email, salesforce_contact_id: anything, platform_user_id: anything)
#            .and_return(portal_user_success)
#          expect{ sync_program_service.run }.to raise_error(SyncSalesforceProgram::SyncSalesforceProgramError)
#        end
#
#        it 'processes more participants after a failure for one' do
#          expect(sync_account_service).to have_received(:run).once
#        end
#
#        it 'sets the failed_participants attribute' do
#          expect(sync_program_service.failed_participants.count).to eq(1)
#          expect(sync_program_service.failed_participants.first.email).to eq(sf_participant_fail.email)
#        end
#
#        it 'sets the count attribute' do
#          expect(sync_program_service.count).to eq(2)
#        end
#      end
#
#      context 'for specific failures' do
#        before(:each) do
#          allow(lms_client).to receive(:find_user_by).with(email: sf_participant_fail.email, salesforce_contact_id: anything, platform_user_id: anything)
#            .and_return(portal_user_fail)
#          allow(lms_client).to receive(:find_user_by).with(email: sf_participant_success.email, salesforce_contact_id: anything, platform_user_id: anything)
#            .and_return(portal_user_success)
#        end
#
#        context 'with invalid Program ID' do
#          let(:error_message) { 'Program Blah not found. Please use a valid program.' }
#          it 'shows a nice error message' do
#            expect(sf_client).to receive(:find_program).and_raise(SalesforceAPI::ProgramNotOnSalesforceError, error_message)
#            expect{ sync_program_service.run }.to raise_error(SalesforceAPI::ProgramNotOnSalesforceError, error_message)
#          end
#        end
#
#        context 'when Canvas User IDs dont match' do
#          it 'shows a nice error message' do
#            user_fail.canvas_user_id= 1
#            portal_user_fail.id = 2
#            expect{ sync_program_service.run }.to raise_error(SyncSalesforceProgram::SyncSalesforceProgramError, /These must match/)
#          end
#        end
#
#        context 'when existing Platform user with same email but different Salesforce Contact ID' do
#          let(:user_fail) { create :registered_user, salesforce_id: '00000000000000000A' }
#          let(:missing_contact_id) { '00000000000000000Z' }
#
#          it 'shows a nice error message' do
#            expect(sf_participant_fail.contact_id).to eq(user_fail.salesforce_id)
#            # Make them not match and sanity check that the new ID doesnt have a platform user.
#            sf_participant_fail.contact_id = missing_contact_id
#            expect(sf_participant_fail.contact_id).not_to eq(user_fail.salesforce_id)
#            expect(User.find_by_salesforce_id(missing_contact_id)).to eq(nil)
#            expect{ sync_program_service.run }.to raise_error(SyncSalesforceProgram::SyncSalesforceProgramError, /We can't create a second user with that email/)
#          end
#        end
#
#        context 'when Zoom meeting has ended' do
#          let(:error_message) { 'We cannot create pre-registered links' }
#          before(:each) do
#            expect(sync_zoom_service).to receive(:run).and_raise(ZoomAPI::ZoomMeetingEndedError, error_message)
#          end
#
#          # Just make sure that this particular error is propogated to the
#          # aggregated error that is used to send the email to help product support troubleshoot.
#          it 'shows a nice error message' do
#            expect{ sync_program_service.run }.to raise_error(SyncSalesforceProgram::SyncSalesforceProgramError, /#{error_message}/)
#          end
#        end
#
#        context 'when invalid email' do
#          let(:error_message) { 'We cannot create a Zoom link for email' }
#          before(:each) do
#            expect(sync_zoom_service).to receive(:run).and_raise(ZoomAPI::BadZoomRegistrantFieldError, error_message)
#          end
#
#          # Just make sure that this particular error is propogated to the
#          # aggregated error that is used to send the email to help product support troubleshoot.
#          it 'shows a nice error message' do
#            expect{ sync_program_service.run }.to raise_error(SyncSalesforceProgram::SyncSalesforceProgramError, /#{error_message}/)
#          end
#        end
#
#        context 'when too many changes requiring a new Zoom link' do
#          let(:error_message) { 'We temporarily cannot create a Zoom link' }
#          before(:each) do
#            expect(sync_zoom_service).to receive(:run).and_raise(ZoomAPI::TooManyRequestsError, error_message)
#          end
#
#          # Just make sure that this particular error is propogated to the
#          # aggregated error that is used to send the email to help product support troubleshoot.
#          it 'shows a nice error message' do
#            expect{ sync_program_service.run }.to raise_error(SyncSalesforceProgram::SyncSalesforceProgramError, /#{error_message}/)
#          end
#        end
#
#        # context 'when syncing Host of Zoom meeting' do
#        #   See: sync_zoom_links_for_participant_spec.rb
#        #   for how the ZoomAPI::HostCantRegisterForZoomMeetingError is handled
#        # end
#      end
#
#    end # END 'with failed participants'
#
#  end # END '#run'

end
