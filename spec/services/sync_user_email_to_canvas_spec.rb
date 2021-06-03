# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncUserEmailToCanvas do
  describe '#run' do
    # Make sure and define canvas_email and platform_email in your tests below
    let(:canvas_login) { create(:canvas_login, unique_id: canvas_email) }
    let!(:user) { create(:registered_user, email: platform_email) }
    let(:canvas_client) { instance_double(CanvasAPI) }

    before do
      allow(canvas_client).to receive(:get_login).and_return(canvas_login)
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    end

    context 'when Platform email matches Canvas login email' do
      context 'when exact match' do
        let(:canvas_email) { 'exact_match@example.com' }
        let(:platform_email) { 'exact_match@example.com' }

        it 'is a NOOP' do
          expect{ SyncUserEmailToCanvas.new(user).run! }.not_to raise_error
          user.reload
          expect(user.email).to eq(platform_email) # Sanity check that platform email didn't change
          # Also, expect canvas_client not to have received any other API calls,
          # but since they're not stubbed this would fail if it happened
        end
      end

      context 'when case insensitive match' do
        let(:canvas_email) { 'CaseInsensitive_match@example.com' }
        let(:platform_email) { 'caseinsensitive_match@example.com' }

        it 'is a NOOP' do
          expect{ SyncUserEmailToCanvas.new(user).run! }.not_to raise_error
          user.reload
          expect(user.email).to eq(platform_email) # Sanity check that platform email didn't change
          # Also, expect canvas_client not to have received any other API calls,
          # but since they're not stubbed this would fail if it happened
        end
      end
    end

    # Imagine a staff member manually changed it in Canvas and messed things up,
    # or if we are running sync logic to change it in Platform. Confirmation handles
    # syncing the two emails so that login works.
    context 'when Platform email doesnt match Canvas login email' do
      let(:canvas_email) { 'canvas.email@example.com' }
      let(:platform_email) { 'platform.email@example.com' }
      let(:canvas_email_channel) { create :canvas_communication_channel, address: canvas_email}

      before(:each) do
        allow(canvas_client).to receive(:update_login)
        allow(canvas_client).to receive(:get_user_communication_channels)
        allow(canvas_client).to receive(:get_user_email_channel)
        allow(canvas_client).to receive(:create_user_email_channel)
        allow(canvas_client).to receive(:delete_user_email_channel)
      end

      shared_examples 'changes Canvas login and communication email' do
        before(:each) do
          allow(canvas_client).to receive(:get_user_email_channel)
            .with(user.canvas_user_id, canvas_email, anything)
            .and_return(canvas_email_channel)
        end

        it 'updates the Canvas login email to match' do
          expect(canvas_client).to receive(:update_login).with(canvas_login['id'], platform_email).once
          SyncUserEmailToCanvas.new(user).run!
        end

        it 'creates a Canvas communication channel with the new login email (and skips confirmation)' do
          expect(canvas_client).to receive(:create_user_email_channel).with(user.canvas_user_id, platform_email, true).once
          SyncUserEmailToCanvas.new(user).run!
        end

        it 'deletes the Canvas communication channel for the old login email' do
          expect(canvas_client).to receive(:delete_user_email_channel).with(user.canvas_user_id, canvas_email).once
          SyncUserEmailToCanvas.new(user).run!
        end
      end

      it_behaves_like 'changes Canvas login and communication email'

      context 'when no communication channel for old login email found' do
        it 'doesnt try to delete it' do
          allow(canvas_client).to receive(:get_user_email_channel).and_return([])
          expect(canvas_client).not_to receive(:delete_user_email_channel)
          SyncUserEmailToCanvas.new(user).run!
        end
      end

      # Can happen if a staff member manually changes the Canvas login email
      context 'when communication channel already exists for platform email' do
        let(:canvas_email_channel) { create :canvas_communication_channel, address: platform_email}

        it 'doesnt try to create it' do
          allow(canvas_client).to receive(:get_user_email_channel)
            .with(user.canvas_user_id, platform_email, anything)
            .and_return(canvas_email_channel)
          expect(canvas_client).not_to receive(:create_user_email_channel)
          SyncUserEmailToCanvas.new(user).run!
        end
      end
    end

  end # END #run

end
