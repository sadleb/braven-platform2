# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncPortalEnrollmentsForProgram do
  let(:fellow_canvas_course_id) { 11 }
  let(:sf_participants) { [] }
  let(:sf_program) { SalesforceAPI::SFProgram.new('00355500001iyvbbbbQ', 'Some Program', 'Some School', fellow_canvas_course_id) }
  let(:lms_client) { double(CanvasAPI, find_user_by: nil) }
  let(:sf_client) { double(SalesforceAPI) }
  let(:sync_account_service) { double(SyncPortalEnrollmentForAccount, run: nil) }

  before(:each) do
    allow(SyncPortalEnrollmentForAccount).to receive(:new).and_return(sync_account_service)
    allow(SalesforceAPI).to receive(:client).and_return(sf_client)
    allow(CanvasAPI).to receive(:client).and_return(lms_client)
    allow(sf_client).to receive(:find_program).and_return(sf_program)
  end

  describe '#run' do
    before(:each) do
      allow(sf_client).to receive(:find_participants_by).with(program_id: sf_program.id).and_return(sf_participants)
    end

    context 'with failed participants' do
      let(:portal_user_success) { CanvasAPI::LMSUser.new(767654, sf_participant_success.email) }
      let(:sf_participant_success) { SalesforceAPI::SFParticipant.new('firstS', 'lastS', 'success1@example.com') }
      let(:sf_participant_fail) { SalesforceAPI::SFParticipant.new('firstF', 'lastF', 'fail1@example.com') }
      # Note the order here matters. fail first, then success
      let(:sf_participants) { [sf_participant_fail, sf_participant_success] }
      let(:sync_program_service) { SyncPortalEnrollmentsForProgram.new(salesforce_program_id: sf_program.id) }

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

  end

  describe '.find_or_create_user!' do
    let(:sync_program_service) { SyncPortalEnrollmentsForProgram.new(salesforce_program_id: sf_program.id) }
    let(:sf_participant) { SalesforceAPI::SFParticipant.new(
      'first',
      'last',
      'test@example.com',
      :role_ignored,
      :program_id_ignored,
      '10',  # contact_id
    ) }

    it 'does not send confirmation emails' do
      Devise.mailer.deliveries.clear()
      expect {
        sync_program_service.send(:find_or_create_user!, sf_participant)
      }.to change(User, :count).by(1)
      expect(Devise.mailer.deliveries.count).to eq 0
    end
  end
end
