# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PortalAccountSetupJob, type: :job do
  describe '#perform' do
    let(:portal_setup) { double('PortalAccountSetup', run: nil) }

    before(:each) do
      allow(PortalAccountSetup).to receive(:new).and_return(portal_setup)
    end

    it 'starts the portal account setup process' do
      PortalAccountSetupJob.perform_now(nil)

      expect(portal_setup).to have_received(:run)
    end
  end
end
