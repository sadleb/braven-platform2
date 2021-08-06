# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncPortalEnrollmentsForProgram do
  let(:fellow_canvas_course_id) { 11 }
  let(:sf_participants) { [] }
  let(:sf_program) { SalesforceAPI::SFProgram.new('00355500001iyvbbbbQ', 'Some Program', 'Some School', fellow_canvas_course_id) }
  let(:lms_client) { double(CanvasAPI, find_user_by: nil) }
  let(:sf_client) { double(SalesforceAPI, update_contact: nil, find_program: sf_program) }
  let(:sync_account_service) { double(SyncPortalEnrollmentForAccount, run: nil) }
  let(:sync_zoom_service) { double(SyncZoomLinksForParticipant, run: nil) }

  before(:each) do
    allow(SyncPortalEnrollmentForAccount).to receive(:new).and_return(sync_account_service)
    allow(SyncZoomLinksForParticipant).to receive(:new).and_return(sync_zoom_service)
    allow(SalesforceAPI).to receive(:client).and_return(sf_client)
    allow(CanvasAPI).to receive(:client).and_return(lms_client)
  end

  describe '#run' do
    before(:each) do
      allow(sf_client).to receive(:find_participants_by).with(program_id: sf_program.id).and_return(sf_participants)
    end

    # These are Participants where we are running Sync From Salesforce for the first time since they
    # were added to the Program. We create a new User record. The primary motivation for this
    # is so that we can allow them to use the password reset flow to sign up and create an
    # account if they lost, can't find, or don't think to look for their welcome email asking
    # them to create an account.
    context 'with new participants' do
      let(:new_sf_participant) { create :salesforce_participant }
      let(:new_sf_participant_struct) { SalesforceAPI.participant_to_struct(new_sf_participant) }
      let(:sf_participants) { [new_sf_participant_struct] }
      let(:new_user) { double(User).as_null_object }

      before(:each) do
        allow(new_user).to receive(:blank?).and_return(false)
        allow(User).to receive(:new).and_return(new_user)
      end

      subject(:run_sync) do
        SyncPortalEnrollmentsForProgram.new(salesforce_program_id: sf_program.id).run
      end

      it 'creates a new User record' do
        expect(new_user).to receive(:save!).once
        run_sync
      end

      context 'when Participant.Status equals Dropped' do
        let(:new_sf_participant) { create :salesforce_participant, :ParticipantStatus => SalesforceAPI::DROPPED }
        it 'does not create a new User record' do
          expect(User).not_to receive(:new)
          run_sync
        end

        it 'does not create Zoom links' do
          expect(sync_zoom_service).not_to receive(:run)
          run_sync
        end

        it 'does not enroll in Canvas' do
          expect(sync_account_service).not_to receive(:run)
          run_sync
        end
      end

      it 'doesnt send a confirmation email' do
        expect(new_user).to receive(:skip_confirmation_notification!).once
        run_sync
      end

      it 'generates signup token' do
        allow(new_user).to receive(:signup_token).and_return(nil)
        expect(new_user).to receive(:set_signup_token!).once
        run_sync
      end

      it 'sends the signup token to Salesforce' do
        fake_token = 'fake_token'
        allow(new_user).to receive(:signup_token).and_return(nil)
        allow(new_user).to receive(:set_signup_token!).and_return(fake_token)
        expect(new_user).to receive(:send_signup_token).with(fake_token).once
        run_sync
      end

      it 'runs the Zoom sync service' do
        force_zoom_updates = false
        expect(SyncZoomLinksForParticipant).to receive(:new).with(new_sf_participant_struct, force_zoom_updates).once
        expect(sync_zoom_service).to receive(:run).once
        run_sync
      end

      # These emails are supposed to come in a welcome email blast a couple weeks before launch.
      # The signup_emails sent from Platform are meant to help staff support issues with getting
      # account access through the normal flow. These are essentially "backup" signup emails that
      # we send in one-off cases.
      it 'defaults to not sending sign-up emails' do
        expect(new_user).not_to receive(:send_signup_email!)
        run_sync
      end

      # The "send_signup_emails" mode is intended to be used by support staff scrambling
      # to get last minute folks access to Canvas. For example, at the first Learning Lab
      # a couple friends show up wanting to do Braven b/c they just heard about it.
      # The staff member would use Salesforce to fully confirm them and create an Enrolled
      # Participant. Then they would run "Sync From Salesforce" with the checkbox to send
      # sign-up emails. That is how they would get the sign-up link to these folks right
      # then and there allowing them to create an account and log in to Canvas.
      context 'when sending sign-up emails is turned on' do
        it 'sends the sign-up email' do
          fake_token = 'fake_token'
          allow(new_user).to receive(:signup_token).and_return(nil)
          allow(new_user).to receive(:set_signup_token!).and_return(fake_token)
          expect(new_user).to receive(:send_signup_email!).with(fake_token).once
          SyncPortalEnrollmentsForProgram.new(salesforce_program_id: sf_program.id, send_signup_emails: true).run
        end
      end
    end

    context 'with failed participants' do
      let(:user_success) { create :registered_user }
      let(:portal_user_success) { CanvasAPI::LMSUser.new(user_success.canvas_user_id, user_success.email) }
      let(:sf_participant_success) {
        sf_part_hash = create :salesforce_participant,
          :ContactId => user_success.salesforce_id,
          :FirstName => user_success.first_name,
          :LastName => user_success.last_name,
          :Email => user_success.email
        SalesforceAPI.participant_to_struct(sf_part_hash)
      }
      let(:user_fail) { create :registered_user }
      let(:portal_user_fail) { CanvasAPI::LMSUser.new(user_fail.canvas_user_id, user_fail.email) }
      let(:sf_participant_fail) {
        sf_part_hash = create :salesforce_participant,
          :ContactId => user_fail.salesforce_id,
          :FirstName => user_fail.first_name,
          :LastName => user_fail.last_name,
          :Email => user_fail.email
        SalesforceAPI.participant_to_struct(sf_part_hash)
      }
      # Note the order here matters. fail first, then success
      let(:sf_participants) { [sf_participant_fail, sf_participant_success] }
      let(:sync_program_service) { SyncPortalEnrollmentsForProgram.new(salesforce_program_id: sf_program.id) }

      context 'for general failure' do
        before(:each) do
          expect(lms_client).to receive(:find_user_by).with(email: sf_participant_fail.email, salesforce_contact_id: anything, student_id: anything)
            .and_raise("Fake Exception")
          expect(lms_client).to receive(:find_user_by).with(email: sf_participant_success.email, salesforce_contact_id: anything, student_id: anything)
            .and_return(portal_user_success)
          expect{ sync_program_service.run }.to raise_error(SyncPortalEnrollmentsForProgram::SyncPortalEnrollmentsForProgramError)
        end

        it 'processes more participants after a failure for one' do
          expect(sync_account_service).to have_received(:run).once
        end

        it 'sets the failed_participants attribute' do
          expect(sync_program_service.failed_participants.count).to eq(1)
          expect(sync_program_service.failed_participants.first.email).to eq(sf_participant_fail.email)
        end

        it 'sets the count attribute' do
          expect(sync_program_service.count).to eq(2)
        end
      end

      context 'for specific failures' do
        before(:each) do
          allow(lms_client).to receive(:find_user_by).with(email: sf_participant_fail.email, salesforce_contact_id: anything, student_id: anything)
            .and_return(portal_user_fail)
          allow(lms_client).to receive(:find_user_by).with(email: sf_participant_success.email, salesforce_contact_id: anything, student_id: anything)
            .and_return(portal_user_success)
        end

        context 'with invalid Program ID' do
          let(:error_message) { 'Program Blah not found. Please use a valid program.' }
          it 'shows a nice error message' do
            expect(sf_client).to receive(:find_program).and_raise(SalesforceAPI::ProgramNotOnSalesforceError, error_message)
            expect{ sync_program_service.run }.to raise_error(SalesforceAPI::ProgramNotOnSalesforceError, error_message)
          end
        end

        context 'when Canvas User IDs dont match' do
          it 'shows a nice error message' do
            user_fail.canvas_user_id= 1
            portal_user_fail.id = 2
            expect{ sync_program_service.run }.to raise_error(SyncPortalEnrollmentsForProgram::SyncPortalEnrollmentsForProgramError, /These must match/)
          end
        end

        context 'when existing Platform user with same email but different Salesforce Contact ID' do
          let(:user_fail) { create :registered_user, salesforce_id: '00000000000000000A' }
          let(:missing_contact_id) { '00000000000000000Z' }

          it 'shows a nice error message' do
            expect(sf_participant_fail.contact_id).to eq(user_fail.salesforce_id)
            # Make them not match and sanity check that the new ID doesnt have a platform user.
            sf_participant_fail.contact_id = missing_contact_id
            expect(sf_participant_fail.contact_id).not_to eq(user_fail.salesforce_id)
            expect(User.find_by_salesforce_id(missing_contact_id)).to eq(nil)
            expect{ sync_program_service.run }.to raise_error(SyncPortalEnrollmentsForProgram::SyncPortalEnrollmentsForProgramError, /We can't create a second user with that email/)
          end
        end

        context 'when Zoom meeting has ended' do
          let(:error_message) { 'We cannot create pre-registered links' }
          before(:each) do
            expect(sync_zoom_service).to receive(:run).and_raise(ZoomAPI::ZoomMeetingEndedError, error_message)
          end

          # Just make sure that this particular error is propogated to the
          # aggregated error that is used to send the email to help product support troubleshoot.
          it 'shows a nice error message' do
            expect{ sync_program_service.run }.to raise_error(SyncPortalEnrollmentsForProgram::SyncPortalEnrollmentsForProgramError, /#{error_message}/)
          end
        end

        context 'when invalid email' do
          let(:error_message) { 'We cannot create a Zoom link for email' }
          before(:each) do
            expect(sync_zoom_service).to receive(:run).and_raise(ZoomAPI::BadZoomRegistrantFieldError, error_message)
          end

          # Just make sure that this particular error is propogated to the
          # aggregated error that is used to send the email to help product support troubleshoot.
          it 'shows a nice error message' do
            expect{ sync_program_service.run }.to raise_error(SyncPortalEnrollmentsForProgram::SyncPortalEnrollmentsForProgramError, /#{error_message}/)
          end
        end

        # context 'when syncing Host of Zoom meeting' do
        #   See: sync_zoom_links_for_participant_spec.rb
        #   for how the ZoomAPI::HostCantRegisterForZoomMeetingError is handled
        # end
      end

    end # END 'with failed participants'

  end # END '#run'

end
