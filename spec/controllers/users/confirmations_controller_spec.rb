require 'rails_helper'
require 'rubycas-server-core/util'

RSpec.describe Users::ConfirmationsController, type: :controller do
  render_views

  # Responsible for showing the page that lets a user resend the confirmation link
  describe '#create' do
    let(:params) { nil }
    let!(:user) { create :unconfirmed_user }

    shared_examples 'resends confirmation link' do
      subject(:run_create) do
        post :create, params: params
      end

      it 'sends the confirmation instructions email' do
        Devise.mailer.deliveries.clear()
        expect(Devise.mailer.deliveries.count).to eq 0
        subject
        expect(Devise.mailer.deliveries.count).to eq 1
      end

      it 'redirects to page telling them to check their email' do
        subject
        expect(response).to redirect_to(new_user_confirmation_path)
      end
    end

    shared_examples 'does not resend confirmation link' do
      subject(:run_create) do
        post :create, params: params
      end

      it 'does not send a confirmation instructions email' do
        Devise.mailer.deliveries.clear()
        expect(Devise.mailer.deliveries.count).to eq 0
        subject
        expect(Devise.mailer.deliveries.count).to eq 0
      end

      # Behave that same as though the request was valid for security purposes
      it 'redirects to page telling them to check their email' do
        subject
        expect(response).to redirect_to(new_user_confirmation_path)
      end
    end

    context 'with confirmation_token' do
      let(:params) { {user: {confirmation_token: token}} }

      context 'for valid token' do
        let(:token) { user.confirmation_token }
        it_behaves_like 'resends confirmation link'
      end

      context 'for invalid token' do
        let(:token) { 'invalid_token' }
        it_behaves_like 'does not resend confirmation link'
      end
    end

    context 'with uuid' do
      let(:params) { {user: {uuid: uuid}} }

      context 'for valid uuid' do
        let(:uuid) { user.uuid }
        it_behaves_like 'resends confirmation link'
      end

      context 'for invalid uuid' do
        let(:uuid) { 'fake_uuid' }
        it_behaves_like 'does not resend confirmation link'
      end
    end
  end

  describe '#confirm' do
    let(:sync_salesforce_contact_service) { double(SyncSalesforceContact, :run => nil) }

    before(:each) do
      allow(SyncSalesforceContact).to receive(:new).and_return(sync_salesforce_contact_service)
    end

    subject(:run_confirm) do
      post :confirm, params: {
        user: { confirmation_token: token }
      }
    end

    shared_examples 'confirmation' do

      context 'for valid token' do
        let(:token) { user.confirmation_token }

        before(:each) do
          allow(sync_salesforce_contact_service).to receive(:validate_already_synced_contact!)
          allow(sync_salesforce_contact_service).to receive(:sync_canvas_email)
        end

        # it 'disallows login before confirmation' do
        #   # See: cas/login_spec.rb
        # end

        it 'confirms the user' do
          run_confirm
          user.reload
          expect(user.confirmed?).to eq(true)
        end

        it 'creates CAS ServiceTicket after confirmation' do
          run_confirm
          st = RubyCAS::Server::Core::Tickets::ServiceTicket.find_by(username: user.email, service: CanvasConstants::CAS_LOGIN_URL)
        end

        # Note: this is essentially testing that it automatically logs you in since this Canvas CAS login
        # URL will take the valid ServiceTicket and call back into the Platform CAS login URL with the
        # ticket and we say "it's valid" so Canvas logs you in.
        it 'redirects to Canvas with CAS ServiceTicket after confirmation' do
          expected_redirect_url = nil
          expect(RubyCAS::Server::Core::Tickets::Utils).to receive(:build_ticketed_url) do |service_url, service_ticket|
            expect(service_url).to eq(CanvasConstants::CAS_LOGIN_URL)
            user.reload # email will change to unconfirmed_email if this was a reconfirmation
            st = RubyCAS::Server::Core::Tickets::ServiceTicket.find_by(username: user.email, service: CanvasConstants::CAS_LOGIN_URL)
            expect(st).to eq(service_ticket)
            expected_redirect_url = "#{CanvasConstants::CAS_LOGIN_URL}?ticket=#{st.ticket}"
            expected_redirect_url
          end

          run_confirm

          expect(response).to redirect_to expected_redirect_url
        end

        context 'when Contact ID not found on Salesforce' do
          it 'rolls back the User models confirmation and email columns' do
            user_before_conf = user
            allow(sync_salesforce_contact_service).to receive(:validate_already_synced_contact!)
              .and_raise(SyncSalesforceProgram::MissingContactError)
            expect{ run_confirm }.to raise_error(SyncSalesforceProgram::MissingContactError)
            expect(User.find(user.id)).to eq(user_before_conf)
          end
        end
      end

      # For security purposes all invalid token behavior should be to give a generic message about
      # confirmation failing, but not exposing any information about the validity of the token or any
      # account information. Note that we pass the invalid token in the redirect so that we can look
      # up the user with it if possible.
      context 'for invalid token' do
        let(:token) { nil }

        context 'when missing confirmation_token param' do
          it 'redirects to show_resend action' do
            post :confirm, params: { }
            expect(response).to redirect_to users_confirmation_show_resend_path(confirmation_token: token)
          end
        end

        context 'when blank token' do
          let(:token) { '' }
          it 'redirects to show_resend action' do
            run_confirm
            expect(response).to redirect_to users_confirmation_show_resend_path(confirmation_token: token)
          end
        end

        context 'when token not in database' do
          let(:token) { 'aaaaa_something_fake' }
          it 'redirects to show_resend action' do
            run_confirm
            expect(response).to redirect_to users_confirmation_show_resend_path(confirmation_token: token)
          end
        end

        context 'when token already consumed' do
          let(:token) { user.confirmation_token }
          it 'redirects to show_resend action' do
            User.confirm_by_token(token)
            run_confirm
            expect(response).to redirect_to users_confirmation_show_resend_path(confirmation_token: token)
          end
        end

        context 'when token expired' do
          let(:token) { user.confirmation_token }
          it 'redirects to show_resend action' do
            user.update!(confirmation_sent_at: 1.year.ago)
            run_confirm
            expect(response).to redirect_to users_confirmation_show_resend_path(confirmation_token: token)
          end
        end
      end # END 'for invalid token'

    end

    context 'with new user' do
      let!(:user) { create :unconfirmed_user }

      it_behaves_like 'confirmation'
    end

    # This is a user who we've changed their email address. The unconfirmed_email column
    # gets set which acts like the confirmed_at column for purposes of determining if the
    # user can login with that email b/c it's been confirmed or not
    context 'with user needing reconfirmation' do
      let!(:user) { create :reconfirmation_user }
      let!(:unconfirmed_email) { user.unconfirmed_email }

      it_behaves_like 'confirmation'

      context 'for valid token' do
        let(:token) { user.confirmation_token }

        before(:each) do
          allow(sync_salesforce_contact_service).to receive(:validate_already_synced_contact!)
          allow(sync_salesforce_contact_service).to receive(:sync_canvas_email)
        end

        #it 'allows old email to still log in before reconfirmation' do
        #  # See: cas/login_spec.rb
        #end

        it 'updates the email attribute to be the unconfirmed_email' do
          expect(user.email).not_to eq(unconfirmed_email) # Sanity check
          run_confirm
          user.reload
          expect(user.email).to eq(unconfirmed_email)
          expect(user.unconfirmed_email).to be(nil)
        end

        #it 'does not allow old email to still log in after reconfirmation' do
        #  # See: cas/login_spec.rb
        #end

        it 'syncs the Canvas email' do
          expect(sync_salesforce_contact_service).to receive(:sync_canvas_email) do
            # Make sure the sync happens after the email is confirmed
            expect(user.reload.email).to eq(unconfirmed_email)
          end
          run_confirm
        end
      end

    end
  end # END #confirm

  # For security purposes, the #show_resend endpoint should not expose any information about the validity
  # of the token or the user account it may be tied to. It's generic and used for all invalid token scenarios
  # where IF the token was actually tied to a user account, then a "Re-Send" would work but not tell you if
  # it did.
  describe '#show_resend' do

    shared_examples 'show resend' do
      let(:token) { nil }

      subject(:run_show_resend) do
        get :show_resend, params: { confirmation_token: token }
      end

      shared_examples 'generic message' do
        it 'shows a generic message with no details about the validity of the token or account tied to it' do
          run_show_resend
          expect(response.body).to match(/Your confirmation link has already been used, has expired, or was invalid/)
        end
      end

      context 'when missing confirmation_token param' do
        it 'shows a generic message with no details about the validity of the token or account tied to it' do
          get :show_resend, params: { }
          expect(response.body).to match(/Your confirmation link has already been used, has expired, or was invalid/)
        end
      end

      context 'when blank token' do
        let(:token) { '' }
        it_behaves_like 'generic message'
      end

      context 'when token not in database' do
        let(:token) { 'aaaaa_something_fake' }
        it_behaves_like 'generic message'
      end

      context 'when token already consumed' do
        let(:token) { user.confirmation_token }
        before(:each) do
          User.confirm_by_token(token)
        end
        it_behaves_like 'generic message'
      end

      context 'when token expired' do
        let(:token) { user.confirmation_token }
        before(:each) do
          user.update!(confirmation_sent_at: 1.year.ago)
        end
        it_behaves_like 'generic message'
      end
    end

    context 'when fully confirmed user' do
      let!(:user) { create :registered_user }
      it_behaves_like 'show resend'
    end

    context 'when unconfirmed user' do
      let!(:user) { create :unconfirmed_user }
      it_behaves_like 'show resend'
    end

    context 'when user needing reconfirmation' do
      let!(:user) { create :registered_user }
      it_behaves_like 'show resend'
    end
  end
end
