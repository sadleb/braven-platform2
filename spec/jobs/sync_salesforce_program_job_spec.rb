# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncSalesforceProgramJob, type: :job do
  describe '#perform' do
    let(:failed_participants) { [] }
    let(:count) { failed_participants.count }
    let(:program_portal_enrollments) { double(SyncSalesforceProgram, run: nil, failed_participants: failed_participants, count: count) }
    let(:delivery) { double('DummyDeliverer', deliver_now: nil) }
    let(:mailer) { double('DummyMailerInstance', success_email: delivery, failure_email: delivery) }

    before(:each) do
      allow(SyncSalesforceProgram).to receive(:new).and_return(program_portal_enrollments)
      allow(SyncSalesforceProgramMailer).to receive(:with).and_return(mailer)
    end

    shared_examples 'starts the sync process' do
      it 'passes salesforce_program_id and force_zoom_update to the sync service' do
        program_id = 'some_fake_id'
        email = 'example@example.com'
        SyncSalesforceProgramJob.perform_now(program_id, email, force_zoom_update)

        expect(SyncSalesforceProgram).to have_received(:new)
          .with(salesforce_program_id: program_id, force_zoom_update: force_zoom_update)
        expect(program_portal_enrollments).to have_received(:run)
      end
    end

    context 'when force_zoom_update is off' do
      let(:force_zoom_update) { false }
      it_behaves_like 'starts the sync process'
    end

    context 'when force_zoom_update is on' do
      let(:force_zoom_update) { true }
      it_behaves_like 'starts the sync process'
    end

    it 'sends success mail if successful' do
      program_id = 'some_fake_id'
      email = 'example@example.com'
      SyncSalesforceProgramJob.perform_now(program_id, email)

      expect(mailer).to have_received(:success_email)
    end

    it 'sends failure mail if something bad happens' do
      allow(program_portal_enrollments).to receive(:run).and_raise('something bad')
      program_id = 'some_fake_id'
      email = 'example@example.com'
      expect{ SyncSalesforceProgramJob.perform_now(program_id, email) }.to raise_error('something bad')
      expect(mailer).to have_received(:failure_email)
    end

  end
end
