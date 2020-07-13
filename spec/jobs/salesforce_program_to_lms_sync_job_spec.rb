# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SalesforceProgramToLmsSyncJob, type: :job do
  describe '#perform' do
    let(:sync_to_lms) { double('SyncToLMS', for_program: nil) }

    before(:each) { allow(SyncToLMS).to receive(:new).and_return(sync_to_lms) }

    it 'starts the sync process for a program id' do
      program_id = 'some_fake_id'

      SalesforceProgramToLmsSyncJob.perform_now(program_id)

      expect(sync_to_lms).to have_received(:for_program).with(program_id)
    end
  end
end
