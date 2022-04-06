# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncSalesforceProgramJob, type: :job do
  describe '#perform' do
    let(:failed_participants) { [] }
    let(:count) { failed_participants.count }
    let(:sync_service) { double(SyncSalesforceProgram, run: nil, failed_participants: failed_participants, count: count) }
    let(:delivery) { double('DummyDeliverer', deliver_now: nil) }
    let(:mailer) { double('DummyMailerInstance', success_email: delivery, failure_email: delivery) }
    let!(:program) { build :heroku_connect_program }

    before(:each) do
      allow(SyncSalesforceProgram).to receive(:new).and_return(sync_service)
      allow(SyncSalesforceProgramMailer).to receive(:with).and_return(mailer)
      allow(HerokuConnect::Program).to receive(:find_by).and_return(program)
    end

    shared_examples 'starts the sync process' do
      let(:force_canvas_update) { false }

      it 'passes the correct params to the sync service' do
        email = 'example@example.com'
        SyncSalesforceProgramJob.perform_async(program.sfid, email, force_canvas_update, force_zoom_update)

        expect(SyncSalesforceProgram).to have_received(:new)
          .with(program, SyncSalesforceProgramJob::SALESFORCE_SYNC_MAX_DURATION, force_canvas_update, force_zoom_update)
        expect(sync_service).to have_received(:run)
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
      email = 'example@example.com'
      SyncSalesforceProgramJob.perform_async(program.id, email)

      expect(mailer).to have_received(:success_email)
    end

    it 'sends failure mail if something bad happens' do
      allow(sync_service).to receive(:run).and_raise('something bad')
      email = 'example@example.com'
      expect{ SyncSalesforceProgramJob.perform_async(program.id, email) }.to raise_error('something bad')
      expect(mailer).to have_received(:failure_email)
    end

  end
end
