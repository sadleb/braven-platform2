# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncFromSalesforceProgramJob, type: :job do
  describe '#perform' do
    let(:failed_participants) { [] }
    let(:count) { failed_participants.count }
    let(:program_portal_enrollments) { double(SyncPortalEnrollmentsForProgram, run: nil, failed_participants: failed_participants, count: count) }
    let(:delivery) { double('DummyDeliverer', deliver_now: nil) }
    let(:mailer) { double('DummyMailerInstance', success_email: delivery, failure_email: delivery) }

    before(:each) do
      allow(SyncPortalEnrollmentsForProgram).to receive(:new).and_return(program_portal_enrollments)
      allow(SyncFromSalesforceProgramMailer).to receive(:with).and_return(mailer)
    end

    shared_examples 'starts the sync process' do
      it 'passes a salesforce_program_id and send_signup_emails to the sync service' do
        program_id = 'some_fake_id'
        email = 'example@example.com'
        SyncFromSalesforceProgramJob.perform_now(program_id, email, send_signup_emails)

        expect(SyncPortalEnrollmentsForProgram).to have_received(:new)
          .with(salesforce_program_id: program_id, send_signup_emails: send_signup_emails)
        expect(program_portal_enrollments).to have_received(:run)
      end
    end

    context 'when send_signup_emails is off' do
      let(:send_signup_emails) { false }
      it_behaves_like 'starts the sync process'
    end

    context 'when send_signup_emails is on' do
      let(:send_signup_emails) { true }
      it_behaves_like 'starts the sync process'
    end

    it 'sends success mail if successful' do
      program_id = 'some_fake_id'
      email = 'example@example.com'
      SyncFromSalesforceProgramJob.perform_now(program_id, email)

      expect(mailer).to have_received(:success_email)
    end

    it 'sends failure mail if something bad happens' do
      allow(program_portal_enrollments).to receive(:run).and_raise('something bad')
      program_id = 'some_fake_id'
      email = 'example@example.com'
      expect{ SyncFromSalesforceProgramJob.perform_now(program_id, email) }.to raise_error('something bad')
      expect(mailer).to have_received(:failure_email)
    end

  end
end
