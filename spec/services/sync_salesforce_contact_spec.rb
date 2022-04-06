# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncSalesforceContact do

# TODO: reimplement specs after this refactoring: https://github.com/bebraven/platform/pull/922
# https://app.asana.com/0/1201131148207877/1201399664994348
# See the old ./spec/services/register_user_account_spec.rb for some of the logic that
# is now here.

  describe '#run' do

    shared_examples 'changes email with no confirmation' do
      # TODO
    end

    shared_examples 'sends email change confirmation email' do
      # TODO
    end

    shared_examples 'changes their first name' do
      # TODO
    end

    shared_examples 'changes their last name' do
      # TODO
    end

    context 'when SignupDate__c fails to send to Salesforce' do
      xit 'does not raise error' do
        # TODO: this won't cause end-user issues, so don't have it fail for them
      end

      xit 'retries on subsequent syncs' do
        # TODO:
      end
    end

    context 'before account creation' do
      it_behaves_like 'changes email with no confirmation'
      it_behaves_like 'changes their first name'
      it_behaves_like 'changes their last name'

      xit 'raises when duplicate Contacts with same email' do
        # TODO: create a second Contact with the same email as someone who already has a Platform account.
        # This should raise DuplicateContactError and should not create a platform user
      end

      xit 'creates a new platform user the first time' do
        # TODO. creates teh user, sends platform id to SF. does not send confirmation email.
      end

      xit 'keeps trying to send the Platform User ID to Salesforce on failures' do
        # TODO: raises proper stuff and keeps trying
      end

      xit 'creates a new Canvas user the first time' do
        # TODO: creates the Canvas user but does not send to Salesforce yet
      end

      xit 'handles Canvas user creation failures' do
        # TODO: raises proper stuff and keeps trying
      end

      xit 'handles Canvas user notification setting failures' do
        # TODO: rescues and doesn't try again in the future. One and done.
      end

      xit 'creates a signup_token and sends to Salesforce' do
        # TODO: also check that it sends the canvas_user_id to SF.
      end

      xit 'handles signup_token creation failures' do
        # TODO: raises proper stuff and keeps trying
      end
    end

    context 'after account creation' do
      it_behaves_like 'sends email change confirmation email'
      it_behaves_like 'changes their first name'
      it_behaves_like 'changes their last name'

      context 'handles out of sync users' do
        # TODO: raises if the SF Contact is missing or the User.canvas_user_id is missing.
        # Alerts if (and eventually auto-corrects) if the canvas user ID or platform user ID in SF
        # don't match (bad merge maybe). If we have a signup token sent at, then we got through the
        # full user creation once, but if they don't match it means they got messed
        # up in SF later (or maybe manually in Platform admin dash?).

        # TODO: tries to fix the SignupDate__c if it failed to send to SF.
      end
    end

  end # '#run'

### OLD specs
#  describe '#run' do
#    let(:sync_user_email_to_canvas_service) { instance_double(SyncUserEmailToCanvas, :run! => nil) }
#
#    before(:each) do
#      allow(SyncUserEmailToCanvas).to receive(:new).and_return(sync_user_email_to_canvas_service)
#    end
#
#    subject(:run_sync) do
#      sf_contact = SalesforceAPI::SFContact.new(
#        salesforce_contact['Id'],
#        salesforce_contact['Email'],
#        salesforce_contact['FirstName'],
#        salesforce_contact['LastName']
#      )
#      SyncSalesforceContact.new(user, sf_contact).run!
#    end
#
#    shared_examples 'run sync' do
#      before(:each) do
#        @user_before_sync = user
#      end
#
#      context 'when Platform email matches Salesforce' do
#        shared_examples 'is a NOOP' do
#          it 'leaves the user unchanged' do
#            run_sync
#            expect(User.find(user.id)).to eq(@user_before_sync)
#          end
#
#          it 'doesnt send reconfirmation email' do
#            Devise.mailer.deliveries.clear()
#            run_sync
#            expect(Devise.mailer.deliveries.count).to eq 0
#          end
#
#          it 'makes sure the Canvas email matches too' do
#            expect(sync_user_email_to_canvas_service).to receive(:run!)
#            run_sync
#          end
#        end
#
#        context 'when exact match' do
#          let(:salesforce_email) { 'exact_match@example.com' }
#          let(:platform_email) { 'exact_match@example.com' }
#          it_behaves_like 'is a NOOP'
#        end
#
#        context 'when case insensitive match' do
#          let(:salesforce_email) { 'caseInsensitiveMatch@example.com' }
#          let(:platform_email) { 'caseinsensitivematch@example.com' }
#          it_behaves_like 'is a NOOP'
#        end
#      end
#
#      context 'when email changes in Salesforce' do
#        let(:salesforce_email) { 'salesforce.email@example.com' }
#        let(:platform_email) { 'platform.email@example.com' }
#
#        # An email update sets the unconfirmed_email column pending reconfirmation.
#        it 'updates the Platform email to match Salesforce' do
#          run_sync
#          user.reload
#          expect(user.unconfirmed_email).to eq(salesforce_email)
#          expect(user.email).to eq(platform_email)
#        end
#
#        it 'sends reconfirmation email' do
#            Devise.mailer.deliveries.clear()
#            run_sync
#            expect(Devise.mailer.deliveries.count).to eq 1
#            expect(user.confirmation_sent_at).not_to be(nil)
#        end
#
#        it 'requires reconfirmation for email change to take effect' do
#          run_sync
#          User.confirm_by_token(user.confirmation_token)
#          user.reload
#          expect(user.unconfirmed_email).to eq(nil)
#          expect(user.email).to eq(salesforce_email)
#        end
#      end
#
#    end
#
#    # Make sure and define salesforce_email, platform_email, and a user with their
#    # email or unconfirmed_email set properly for what you are testing below.
#
#    let(:salesforce_contact) { create(:salesforce_contact, :Email => salesforce_email) }
#
#    context 'when registered user' do
#      let!(:user) { create(:registered_user, email: platform_email) }
#      it_behaves_like 'run sync'
#    end
#
#    context 'when unregistered user' do
#      let!(:user) { create(:unregistered_user, email: platform_email) }
#      it_behaves_like 'run sync'
#    end
#
#    context 'when user already pending reconfirmation of new email' do
#      let!(:user) { create(:reconfirmation_user, email: platform_email) }
#
#      it_behaves_like 'run sync'
#
#      context 'when reconfirmation email already sent' do
#        let(:salesforce_email) { 'salesforce.email@example.com' }
#        let(:platform_email) { 'platform.email@example.com' }
#        let!(:user) { create(:reconfirmation_user, email: platform_email, unconfirmed_email: salesforce_email) }
#
#        it 'doesnt send a second reconfirmation email' do
#          Devise.mailer.deliveries.clear()
#          run_sync
#          expect(Devise.mailer.deliveries.count).to eq 0
#        end
#      end
#    end
#
#  end
end
