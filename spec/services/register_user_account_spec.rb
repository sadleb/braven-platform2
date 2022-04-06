# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RegisterUserAccount do
  describe '#run' do
    let(:contact) { build(:heroku_connect_contact) }
    let!(:user) { create(:unregistered_user, salesforce_id: contact.sfid) }
    let(:raw_signup_token) { user.set_signup_token! }
    let(:sign_up_params) { {password: 'Val!dPassw0rd', password_confirmation: 'Val!dPassw0rd', signup_token: raw_signup_token} }
    let(:sf_client) { instance_double(SalesforceAPI,
      update_contact: nil,
    ) }

    before do
      allow(SalesforceAPI).to receive(:client).and_return(sf_client)
      allow(HerokuConnect::Contact).to receive(:find_by).and_return(contact)
    end

    shared_examples 'valid token' do
      it 'clears signup/reset tokens' do
        # Clear tokens for security reasons.
        RegisterUserAccount.new(user, sign_up_params).run do |u|
          expect(u.errors.any?).to eq(false)
        end
        user.reload
        expect(user.reset_password_token).to eq(nil)
        expect(user.reset_password_sent_at).to eq(nil)
        expect(user.signup_token).to eq(nil)

        # We always keep the sent_at value to determine whether initially we've successfully
        # created a new user to the point that they can sign up. The token is nil, so this
        # is still secure.
        expect(user.signup_token_sent_at).not_to eq(nil)
      end

      it 'updates Salesforce' do
        # Need to freeze now so that it matches
        allow(DateTime).to receive(:now).and_return(DateTime.now)
        RegisterUserAccount.new(user, sign_up_params).run
        expect(sf_client).to have_received(:update_contact)
          .with(contact.sfid, {:Signup_Date__c=> DateTime.now.utc}).once
      end

      it 'sends confirmation instructions to user' do
        Devise.mailer.deliveries.clear()
        RegisterUserAccount.new(user, sign_up_params).run
        expect(Devise.mailer.deliveries.count).to eq 1
        expect(user.confirmation_sent_at).not_to be(nil)
      end

      # Note that only a local missing canvas_user_id or salesforce_id causes an out of sync user
      # to raise. If they are mismatched in Salesforce, it doesn't impact end user functionality
      # so it alerts but doesn't raise.
      context 'with out of sync user' do
        let(:sync_contact_service) { instance_double(SyncSalesforceContact) }
        before :each do
          allow(SyncSalesforceContact).to receive(:new).and_return(sync_contact_service)
          allow(sync_contact_service).to receive(:validate_already_synced_contact!).and_raise
        end

        it 'raises error' do
          expect{RegisterUserAccount.new(user, sign_up_params).run}.to raise_error
        end

        it 'does not consume tokens' do
          expect{RegisterUserAccount.new(user, sign_up_params).run}
          .to raise_error
          .and avoid_changing(user, :signup_token)
          .and avoid_changing(user, :reset_password_token)
        end
      end
    end

    context 'with valid signup token' do
      let(:sign_up_params) { {} }
      let!(:user) { create(:unregistered_user_with_valid_signup_token, contact: contact) }

      before :each do
        sign_up_params[:signup_token] = raw_signup_token
      end

      it_behaves_like 'valid token'
    end

    context 'with valid reset token' do
      let(:sign_up_params) { {} }
      let!(:user) { create(:unregistered_user, signup_token_sent_at: DateTime.now, contact: contact) }

      before :each do
        sign_up_params[:reset_password_token] = user.send(:set_reset_password_token)
      end

      it_behaves_like 'valid token'
    end

    context 'with expired signup_token' do
      let(:sign_up_params) { {} }
      let(:user) { create(:unregistered_user) }

      before :each do
        sign_up_params[:signup_token] = user.set_signup_token!
        user.update!(signup_token_sent_at: 5.weeks.ago)
      end

      it 'yields error and returns' do
        errors = []
        RegisterUserAccount.new(user, sign_up_params).run do |u|
          errors = u.errors
        end
        user.reload
        expect(errors.count).to eq(1)
        expect(errors.first.attribute).to eq(:signup_token)
        expect(errors.first.type).to eq(:expired)
        # Verify it returned before updating user.
        expect(user.signup_token).not_to eq(nil)
      end
    end

    context 'with expired reset token' do
      let(:sign_up_params) { {} }
      let(:user) { create(:unregistered_user) }

      before :each do
        sign_up_params[:reset_password_token] = user.send(:set_reset_password_token)
        user.update!(reset_password_sent_at: 5.days.ago)
      end

      it 'yields error and returns' do
        errors = []
        RegisterUserAccount.new(user, sign_up_params).run do |u|
          errors = u.errors
        end
        user.reload
        expect(errors.count).to eq(1)
        expect(errors.first.attribute).to eq(:reset_password_token)
        expect(errors.first.type).to eq(:expired)
        # Verify it returned before updating user.
        expect(user.reset_password_token).not_to eq(nil)
      end
    end

  end
end
