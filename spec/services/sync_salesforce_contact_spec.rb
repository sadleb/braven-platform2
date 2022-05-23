# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncSalesforceContact do
  let(:program) { build :heroku_connect_program_launched }
  let(:last_sync_info) { create :participant_sync_info_fellow, program: program, contact: contact }
  let(:new_sync_info) {
    nsi = last_sync_info.dup
    nsi.sfid = last_sync_info.sfid # dup doesn't copy primary keys
    nsi
  }
  let(:participant) {
    ParticipantSyncInfo::Diff.new(last_sync_info, new_sync_info)
  }
  let(:sf_client) { instance_double(SalesforceAPI) }
  let(:canvas_client) { instance_double(CanvasAPI) }

  # Defaults. Make sure and set these to match what you are testing below.
  let(:salesforce_email) { 'exact_match@example.com' }
  let(:platform_email) { 'exact_match@example.com' }
  let(:contact) { build :heroku_connect_contact, email: salesforce_email }
  let!(:user) { create :unregistered_user, email: platform_email, contact: contact }

  before(:each) do
    allow(HerokuConnect::Contact).to receive(:find_by).and_return(contact)
    allow(HerokuConnect::Program).to receive(:find).and_return(program)
    allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    allow(SalesforceAPI).to receive(:client).and_return(sf_client)
    allow(Honeycomb).to receive(:add_alert)
    allow(Honeycomb).to receive(:add_support_alert)
    allow(Honeycomb).to receive(:add_field)
  end

  describe '#run' do
    subject(:run_sync) do
      SyncSalesforceContact.new(participant.contact_id, participant.program.time_zone).run
    end

    shared_examples 'when no changes' do
      it 'is NOOP when' do
        expect(user).not_to receive(:save!)
        expect(CanvasAPI).not_to receive(:client)
        expect(SalesforceAPI).not_to receive(:client)
        run_sync
      end
    end

    shared_examples 'handles name changes' do
      it 'changes their first name locally if it changes in Salesforce' do
        user.update!(first_name: "#{user.first_name}_old")
        expect{run_sync}.to change{user.reload.first_name}.to contact.first_name
      end

      it 'changes their last name locally if it changes in Salesforce' do
        user.update!(last_name: "#{user.last_name}_old")
        expect{run_sync}.to change{user.reload.last_name}.to contact.last_name
      end
    end

    shared_examples 'when Platform email matches Salesforce' do
      shared_examples 'is a NOOP' do
        it 'leaves the user unchanged' do
          run_sync
          expect(User.find(user.id)).to eq(user)
        end

        it 'doesnt send reconfirmation email' do
          Devise.mailer.deliveries.clear()
          run_sync
          expect(Devise.mailer.deliveries.count).to eq 0
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

    context 'before account creation' do
      let(:contact) { build :heroku_connect_contact, email: salesforce_email, canvas_cloud_user_id__c: nil, platform_user_id__c: nil }
      let(:user) { create :unregistered_user, email: platform_email, contact: contact }
      let(:canvas_user) { create :canvas_user }
      let(:last_sync_info) { create :participant_sync_info_fellow, user: user, program: program, contact: contact }

      before(:each) do
        expect(contact.signup_date__c).to be(nil)
        allow(sf_client).to receive(:update_contact)
        allow(canvas_client).to receive(:create_user).and_return(canvas_user)
        allow(canvas_client).to receive(:disable_user_grading_emails)
      end

      it_behaves_like 'handles name changes'

      context 'on first time sync' do
        let(:user) { build :unregistered_user, email: platform_email, contact: contact }
        let(:last_sync_info) { build :participant_sync_info_fellow, user: user, program: program, contact: contact }

        context 'when duplicate Contacts with same email' do
          let!(:duplicate_user) { create :unregistered_user_with_valid_signup_token, contact: duplicate_contact }
          let!(:duplicate_contact) { build :heroku_connect_contact, email: contact.email }
          it 'raises DuplicateContactError' do
            expect(Honeycomb).to receive(:add_support_alert).with('save_user_failed', /There are duplicate Contacts/, :error).once
            expect{run_sync}.to raise_error(SyncSalesforceProgram::DuplicateContactError)
          end
        end

        it 'creates a new platform user the first time without sending a confirmation email' do
          expect(User).to receive(:new).and_return(user)
          expect(user).to receive(:skip_confirmation_notification!).once
          expect(user).to receive(:save!).at_least(:once)
          salesforce_contact_fields_to_set = {
            'Platform_User_ID__c': user.id
          }
          expect(sf_client).to receive(:update_contact).with(user.salesforce_id, salesforce_contact_fields_to_set).once
          run_sync
        end

        it 'creates a new Canvas user the first time with disabled grading email notifications' do
          expect(canvas_client).to receive(:disable_user_grading_emails).with(canvas_user['id']).once
          expect(canvas_client).to receive(:create_user) do |first_name, last_name, email, sis_id, time_zone|
            user = User.find_by_email(email)
            expect(first_name).to eq(user.first_name)
            expect(last_name).to eq(user.last_name)
            expect(email).to eq(user.email)
            expect(sis_id).to eq(user.sis_id)

            canvas_user
          end
          run_sync
          expect(User.find_by_salesforce_id(user.salesforce_id).canvas_user_id).to eq(canvas_user['id'])
        end

        it 'creates a signup_token and sends to Salesforce' do
          raw_signup_token = 'fake_token'
          salesforce_contact_fields_to_set = {
            'Canvas_Cloud_User_ID__c': canvas_user['id'],
            'Signup_Token__c': raw_signup_token,
          }
          expect(User).to receive(:new).and_return(user)
          expect(user).to receive(:set_signup_token!) do
            raw_signup_token
          end
          expect(sf_client).to receive(:update_contact).with(user.salesforce_id, salesforce_contact_fields_to_set)
          run_sync
        end

        it 'handles Canvas user notification setting failures' do
          expect(canvas_client).to receive(:disable_user_grading_emails).and_raise(RestClient::Exception)
          expect{run_sync}.not_to raise_error
        end
      end

      context 'on subsequent syncs' do
        let(:contact) { build :heroku_connect_contact, email: salesforce_email }
        let(:user) { create :unregistered_user_with_valid_signup_token, email: platform_email, contact: contact }

        it_behaves_like 'when no changes'
        it_behaves_like 'when Platform email matches Salesforce'

        context 'when email changes in Salesforce' do
          let(:salesforce_email) { 'salesforce.email@example.com' }
          let(:platform_email) { 'platform.email@example.com' }

          it 'updates the Platform email to match Salesforce' do
            expect(user.email).to eq(platform_email) # sanity check
            run_sync
            user.reload
            expect(user.unconfirmed_email).to be(nil)
            expect(user.email).to eq(salesforce_email)
          end

          it 'does not send a reconfirmation email' do
              Devise.mailer.deliveries.clear()
              run_sync
              expect(Devise.mailer.deliveries.count).to eq 0
          end
        end

        it 'keeps trying to send the Platform User ID to Salesforce on failures' do
          user
          contact.platform_user_id__c = nil # mimic it having not been saved in SF properly
          # first sync fails
          expect(sf_client).to receive(:update_contact).and_raise(RestClient::Exception)
          expect{run_sync}.to raise_error(SyncSalesforceProgram::UserSetupError)
          # second sync works
          salesforce_contact_fields_to_set = {
            'Platform_User_ID__c': user.id
          }
          expect(sf_client).to receive(:update_contact).with(user.salesforce_id, salesforce_contact_fields_to_set).once
          run_sync
        end

        context 'when CanvasAPI fails to create user' do
          # mimic having not called the CanvasAPI and saved the ID properly.
          let(:user) { create :unregistered_user_with_valid_signup_token, email: platform_email, contact: contact, canvas_user_id: nil}

          it 'keeps trying' do
            # first sync fails
            expect(canvas_client).to receive(:create_user).and_raise(RestClient::Exception)
            expect{run_sync}.to raise_error(SyncSalesforceProgram::UserSetupError)
            # second sync works
            expect(canvas_client).to receive(:create_user).and_return(canvas_user).once
            expect{run_sync}.to change{user.reload.canvas_user_id}.to canvas_user['id']
          end
        end

        context 'when signup_token fails to send to Salesforce' do
          let(:user) { create :unregistered_user, email: platform_email, contact: contact }

          it 'keeps trying' do
            # first sync fails
            expect(sf_client).to receive(:update_contact).and_raise(RestClient::Exception)
            expect{run_sync}.to raise_error(SyncSalesforceProgram::UserSetupError)
            # second sync works
            expect(User).to receive(:find_by).and_return(user)
            expect(user).to receive(:set_signup_token!).and_wrap_original do |m, *args|
              raw_signup_token = m.call(*args)
              salesforce_contact_fields_to_set = {
                'Canvas_Cloud_User_ID__c': user.canvas_user_id,
                'Signup_Token__c': raw_signup_token,
              }
              expect(sf_client).to receive(:update_contact).with(user.salesforce_id, salesforce_contact_fields_to_set).once
              raw_signup_token
            end
            expect{run_sync}.to change{user.reload.signup_token_sent_at}.from(nil).to be_a(ActiveSupport::TimeWithZone)
          end
        end
      end
    end

    context 'after account creation' do
      let(:contact) { build :heroku_connect_contact_signed_up, email: salesforce_email }
      let(:user) { create :registered_user, email: platform_email, contact: contact }
      let(:last_sync_info) { create :participant_sync_info_fellow, user: user, program: program, contact: contact }

      it_behaves_like 'when no changes'
      it_behaves_like 'handles name changes'
      it_behaves_like 'when Platform email matches Salesforce'

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
            expect(user.reload.confirmation_sent_at).not_to be(nil)
        end

        it 'requires reconfirmation for email change to take effect' do
          run_sync
          User.confirm_by_token(user.reload.confirmation_token)
          expect(user.reload.unconfirmed_email).to eq(nil)
          expect(user.reload.email).to eq(salesforce_email)
        end
      end

      context 'handles out of sync users' do

        context 'when Salesforce Contact is missing' do
          # Can happen due to bad merge.
          it 'raises error' do
            expect(HerokuConnect::Contact).to receive(:find_by).and_return(nil)
            expect{run_sync}.to raise_error(SyncSalesforceProgram::MissingContactError)
          end
        end

        context 'when local Canvas User ID doesnt match Salesforce' do
          it 'alerts support but doesnt raise error' do
            user.update!(canvas_user_id: user.canvas_user_id + 1)
            expect(Honeycomb).to receive(:add_support_alert)
              .with('mismatched_canvas_user_id', /doesn't have their 'Canvas User ID' field set properly in Salesforce/, :warn).once
            expect{run_sync}.not_to raise_error
          end
        end

        context 'when local User ID doesnt match Salesforce' do
          it 'alerts support but doesnt raise error' do
            contact.platform_user_id__c = user.id + 1
            expect(Honeycomb).to receive(:add_support_alert)
              .with('mismatched_platform_user_id', /doesn't have their 'Platform User ID' field set properly in Salesforce/, :warn).once
            expect{run_sync}.not_to raise_error
          end
        end

        # When they go to register and create an account, we don't fail the registration
        # process if the signup date failed to be sent to Salesforce b/c it doesn't effect
        # the end user. We keep trying to sync that though so it'll eventually get there
        # and we have accurate dashboards.
        context 'when Signup_Date__c not saved in Salesforce' do
          it 'sends the registered_at date to Salesforce' do
            contact.signup_date__c = nil
            # in memory, the precision is like 9 digits. But writing/reading from the DB loses a little,
            # so we need to round for it to match. Alternatively, we could implement a custom matcher like this:
            # https://dev.to/jbranchaud/custom-rspec-matcher-for-comparing-datetimes-542b
            registered_at = Time.zone.now.round(6)
            user.update!(registered_at: registered_at)
            salesforce_contact_fields_to_set = {
              'Signup_Date__c': registered_at
            }
            expect(sf_client).to receive(:update_contact).with(user.salesforce_id, salesforce_contact_fields_to_set).once
            run_sync
          end
        end
      end
    end

  end # '#run'
end
