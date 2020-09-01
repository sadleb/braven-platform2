# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountCreation do
  describe '#run' do
    let(:sf_client) { double('SalesforceAPI', find_contact: SalesforceAPI::SFContact.new) }
    let(:platform_user) { double('User', save: nil, skip_confirmation_notification!: nil) }

    before(:each) do
      allow(SalesforceAPI).to receive(:client).and_return(sf_client)
      allow(User).to receive(:new).and_return(platform_user)
      allow(PortalAccountSetupJob).to receive(:perform_later).and_return(nil)
    end

    it 'queues up portal account setup job' do
      AccountCreation.new(sign_up_params: {}).run

      expect(PortalAccountSetupJob).to have_received(:perform_later).with(nil)
    end

    it 'create a user and persists a user' do
      AccountCreation.new(sign_up_params: {}).run

      expect(platform_user).to have_received(:save)
    end

    it 'skips confirmation notification' do
      AccountCreation.new(sign_up_params: {}).run

      expect(platform_user).to have_received(:skip_confirmation_notification!)
    end
  end
end
