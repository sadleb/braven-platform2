# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateTestUsersJob, type: :job do
  describe '#perform' do
    let(:failed_users) { [] }
    let(:user_contact_ids) { [] }
    let(:success_users) { [] }
    let(:programs_to_sync) { [] }
    let(:sync_error) { { message: 'sync error' } }
    let(:generate_service) { double(GenerateTestUsers,
      run: nil,
      sync_error_message: sync_error,
      failed_users: failed_users,
      user_contact_ids: user_contact_ids,
      success_users: success_users,
      programs_to_sync: programs_to_sync,
      sync_error: sync_error
    ) }
    let(:params) { { 'test_params' => 'test_params' } }
    let(:email) { 'example@example.com' }
    let(:delivery) { double('DummyDeliverer', deliver_now: nil) }
    let(:mailer) { double('DummyMailerInstance', success_email: delivery, failure_email: delivery) }

    before(:each) do
      allow(GenerateTestUsers).to receive(:new).and_return(generate_service)
      allow(GenerateTestUsersMailer).to receive(:with).and_return(mailer)
    end

    it 'sends success mail if successful' do
      GenerateTestUsersJob.perform_now(email, params)
      expect(mailer).to have_received(:success_email)
    end

    it 'sends failure mail if something bad happens' do
      allow(generate_service).to receive(:run).and_raise(StandardError, "error raised")
      expect{ GenerateTestUsersJob.perform_now(email, params) }.to raise_error("error raised")
      expect(mailer).to have_received(:failure_email)
    end
  end
end