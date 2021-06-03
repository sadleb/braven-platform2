# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncFromSalesforceContact do
  describe '#run' do
    let(:sync_user_email_to_canvas_service) { instance_double(SyncUserEmailToCanvas, :run! => nil) }

    before(:each) do
      allow(SyncUserEmailToCanvas).to receive(:new).and_return(sync_user_email_to_canvas_service)
    end

    subject(:run_sync) do
      sf_contact = SalesforceAPI::SFContact.new(
        salesforce_contact['Id'],
        salesforce_contact['Email'],
        salesforce_contact['FirstName'],
        salesforce_contact['LastName']
      )
      SyncFromSalesforceContact.new(user, sf_contact).run!
    end

    shared_examples 'run sync' do
      before(:each) do
        @user_before_sync = user
      end

      context 'when Platform email matches Salesforce' do
        shared_examples 'is a NOOP' do
          it 'leaves the user unchanged' do
            run_sync
            expect(User.find(user.id)).to eq(@user_before_sync)
          end

          it 'doesnt send reconfirmation email' do
            Devise.mailer.deliveries.clear()
            run_sync
            expect(Devise.mailer.deliveries.count).to eq 0
          end

          it 'makes sure the Canvas email matches too' do
            expect(sync_user_email_to_canvas_service).to receive(:run!)
            run_sync
          end
        end

        context 'when exact match' do
          let(:salesforce_email) { 'exact_match@example.com' }
          let(:platform_email) { 'exact_match@example.com' }
          it_behaves_like 'is a NOOP'
        end

        context 'when case insensitive match' do
          let(:salesforce_email) { 'caseInsensitiveMatch@example.com' }
          let(:platform_email) { 'caseinsensitivematch@example.com' }
          it_behaves_like 'is a NOOP'
        end
      end

      context 'when email changes in Salesforce' do
        let(:salesforce_email) { 'salesforce.email@example.com' }
        let(:platform_email) { 'platform.email@example.com' }

        # An email update sets the unconfirmed_email column pending reconfirmation.
        it 'updates the Platform email to match Salesforce' do
          run_sync
          user.reload
          expect(user.unconfirmed_email).to eq(salesforce_email)
          expect(user.email).to eq(platform_email)
        end

        it 'sends reconfirmation email' do
            Devise.mailer.deliveries.clear()
            run_sync
            expect(Devise.mailer.deliveries.count).to eq 1
            expect(user.confirmation_sent_at).not_to be(nil)
        end

        it 'requires reconfirmation for email change to take effect' do
          run_sync
          User.confirm_by_token(user.confirmation_token)
          user.reload
          expect(user.unconfirmed_email).to eq(nil)
          expect(user.email).to eq(salesforce_email)
        end
      end

    end

    # Make sure and define salesforce_email, platform_email, and a user with their
    # email or unconfirmed_email set properly for what you are testing below.

    let(:salesforce_contact) { create(:salesforce_contact, :Email => salesforce_email) }

    context 'when registered user' do
      let!(:user) { create(:registered_user, email: platform_email) }
      it_behaves_like 'run sync'
    end

    context 'when unregistered user' do
      let!(:user) { create(:unregistered_user, email: platform_email) }
      it_behaves_like 'run sync'
    end

    context 'when user already pending reconfirmation of new email' do
      let!(:user) { create(:reconfirmation_user, email: platform_email) }

      it_behaves_like 'run sync'

      context 'when reconfirmation email already sent' do
        let(:salesforce_email) { 'salesforce.email@example.com' }
        let(:platform_email) { 'platform.email@example.com' }
        let!(:user) { create(:reconfirmation_user, email: platform_email, unconfirmed_email: salesforce_email) }

        it 'doesnt send a second reconfirmation email' do
          Devise.mailer.deliveries.clear()
          run_sync
          expect(Devise.mailer.deliveries.count).to eq 0
        end
      end
    end

  end
end
