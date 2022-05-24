# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateTestUsers do
  let(:params) { {
    'first_name' => ['test_first'],
    'role' => ['test_fellow'],
    'tag' => ['test_user_create'],
    'email' => ['test@test.com'],
    'program_id' => ['12345'],
    'cohort_schedule' => ['test_tuesday'],
    'cohort_section' => ['tuesday'],
    'ta' => ['test_ta']
  } }
  let(:sf_client) { double(SalesforceAPI) }
  let(:generate_test_users) { GenerateTestUsers.new(params) }
  let(:new_contact) { {'id' => '123'} }
  let(:new_candidate) { {'id' => '234'} }
  let(:new_participant) { {'id' => '345'} }
  let(:new_ta_assignment) { {'id' => '456'} }
  let(:signup_token) { 'fake_signup_token' }
  let(:sync_salesforce_program_job) { instance_double(SyncSalesforceProgramJob) }
  let(:failed_users) { [] }

  before(:each) do
    allow(SalesforceAPI).to receive(:client).and_return(sf_client)
    allow(sf_client).to receive(:create_or_update_contact).and_return(new_contact)
    allow(sf_client).to receive(:create_candidate).and_return(new_candidate)
    allow(sf_client).to receive(:create_participant).and_return(new_participant)
    allow(sf_client).to receive(:update_candidate).and_return(new_candidate)
    allow(sf_client).to receive(:create_ta_assignment).and_return(new_ta_assignment)
    allow(sf_client).to receive(:get_contact_signup_token).and_return(signup_token)
    allow(SyncSalesforceProgramJob).to receive(:new).and_return(sync_salesforce_program_job)
    allow(sync_salesforce_program_job).to receive(:perform).and_return(nil)
  end

  describe '#run' do
    subject(:run_generate) do
      generate_test_users.run
    end

    context 'with no errors' do
      it 'does not raise' do
        expect{ subject }.not_to raise_error
      end
    end

    context 'with failed users' do
      before(:each) do
        generate_test_users.instance_variable_set(:@failed_users, ['failed_user'])
      end

      it 'raises GenerateTestUsersError' do
        expect{ subject }.to raise_error GenerateTestUsers::GenerateTestUsersError
      end
    end

    context 'with a sync error' do
      before(:each) do
        generate_test_users.instance_variable_set(:@sync_error, 'error with sync')
      end

      it 'raises GenerateTestUsersError' do
        expect{ subject }.to raise_error 'error with sync'
      end
    end
  end
end