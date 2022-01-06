require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  render_views
  include Rails.application.routes.url_helpers

  let!(:user) { create :registered_user }
  let(:admin_user) { create :admin_user }

  # This should return the minimal set of attributes required to create a valid
  # User. As you add validations to User, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) { attributes_for(:registered_user) }

  let(:invalid_attributes) { { name: user.first_name } }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # UsersController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  describe 'when logged in' do
    before do
      sign_in admin_user
    end

    describe "GET #index" do
      it "returns a success response" do
        get :index, params: {}, session: valid_session
        expect(response).to be_successful
      end
    end

    describe "GET #show" do

      subject(:run_show) do
        get :show, params: { id: user.id }
      end

      shared_examples 'success' do
        it "returns a success response" do
          run_show
          expect(response).to be_successful
        end
      end

      context 'for unregistered, unconfirmed user' do
        let(:user) { create :unregistered_user_with_valid_signup_token }

        it_behaves_like 'success'

        it 'doesnt show the "Send Confirmation Email" button' do
          run_show
          expect(response.body).not_to match(/send_confirm_email/)
        end

        context 'with a valid signup token' do
          it 'shows the "Send New Sign-Up Email" button' do
            run_show
            expect(response.body).to match(/<a.*href="\/users\/#{user.id.to_s}\/send_new_signup_email">Send New Sign-up Email\<\/a\>/)
          end
        end

        context 'with an invalid signup token' do
          let(:user) { create :unregistered_user_with_invalid_signup_token }
          it 'shows the "Generate Valid Sign-up Link And Send New Sign-Up Email" button' do
            run_show
            expect(response.body).to match(/<a.*href="\/users\/#{user.id.to_s}\/send_new_signup_email">Generate Valid Sign-up Link And Send New Sign-up Email\<\/a\>/)
          end
        end
      end

      context 'for registered, but unconfirmed user' do
        let(:user) { create :unconfirmed_user }

        # This email is a link to register. We don't want registered folks to use that.
        it 'doesnt show "Send New Sign-Up Email" button' do
          run_show
          expect(response.body).not_to match(/send_new_signup_email/)
        end

        it 'shows the "Send Confirmation Email" button' do
          run_show
          expect(response.body).to match(/<a.*href="\/users\/#{user.id.to_s}\/send_confirm_email">Send Confirmation Email\<\/a\>/)
        end
      end

      context 'for registered user and confirmed user' do
        let(:user) { create :registered_user }

        it 'doesnt show "Send New Sign-Up Email" button' do
          run_show
          expect(response.body).not_to match(/send_new_signup_email/)
        end

        it 'doesnt show the "Send Confirmation Email" button' do
          run_show
          expect(response.body).not_to match(/send_confirm_email/)
        end
      end
    end

    describe "GET #new" do
      it "returns a success response" do
        get :new, params: { id: user.id }
        expect(response).to be_successful
      end
    end

    describe "GET #edit" do
      it "returns a success response" do
        get :edit, params: { id: user.id }
        expect(response).to be_successful
      end
    end

    describe "POST #create" do
      let(:user) { build :registered_user }

      context "with valid parameters" do
        it "creates a new user" do
          expect {
            post :create, params: { user: valid_attributes }
          }.to change(User, :count).by(1)
        end

        it "automatically confirms the user" do
          post :create, params: { user: valid_attributes }
          expect(User.last.confirmed_at).not_to be(nil)
        end

        it "automatically registers the user" do
          post :create, params: { user: valid_attributes }
          expect(User.last.registered_at).not_to be(nil)
        end
      end

      context "with invalid parameters" do
        it "does not create a user" do
          expect {
            post :create, params: { user: invalid_attributes }
          }.not_to change { User.count }
        end
      end
    end

    describe "POST #send_confirm_email" do

      subject(:run_send_confirm_email) do
        post :send_confirm_email, params: { id: user.id }
      end

      context 'for aleady registered' do
        context 'but unconfirmed user' do
          let(:user) { create :unconfirmed_user }
          it 'sends the email' do
            Devise.mailer.deliveries.clear()
            expect(Devise.mailer.deliveries.count).to eq 0
            run_send_confirm_email
            expect(Devise.mailer.deliveries.count).to eq 1
          end
        end

        # The button to get here shouldnt have been shown. They are already confirmed
        context 'and confirmed user' do
          let(:user) { create :registered_user }
          it 'raises error' do
            expect{ run_send_confirm_email }.to raise_error(UsersController::UserAdminError)
          end
        end
      end

      context 'for unregistered user' do
        let(:user) { create :unregistered_user }

        # The button to get here shouldnt have been shown. They need to create their account first.
        it 'raises error' do
          expect{ run_send_confirm_email }.to raise_error(UsersController::UserAdminError)
        end
      end
    end


    describe "GET #show_send_signup_email" do

      subject(:run_show_send_signup_email) do
        get :show_send_signup_email, params: { id: user.id }
      end

      # The button to get here shouldnt have been shown. They are already registered
      context 'for aleady registered' do
        context 'but unconfirmed user' do
          let(:user) { create :unconfirmed_user }
          it 'raises error' do
            expect{ run_show_send_signup_email }.to raise_error(UsersController::UserAdminError)
          end
        end

        context 'and confirmed user' do
          let(:user) { create :registered_user }
          it 'raises error' do
            expect{ run_show_send_signup_email }.to raise_error(UsersController::UserAdminError)
          end
        end
      end

      context 'for unregistered user' do
        let(:user) { create :unregistered_user }
        it 'shows the button to send the email' do
          run_show_send_signup_email
          expect(response.body).to match(/#{Regexp.escape('<input type="submit" name="commit" value="Send New Sign Up Email Now"')}/)
        end
      end
    end

    describe "POST #send_signup_email" do

      subject(:run_send_signup_email) do
        post :send_signup_email, params: { id: user.id }
      end

      # The button to get here shouldnt have been shown. They are already registered
      context 'for aleady registered' do
        context 'but unconfirmed user' do
          let(:user) { create :unconfirmed_user }
          it 'raises error' do
            expect{ run_send_signup_email }.to raise_error(UsersController::UserAdminError)
          end
        end

        context 'and confirmed user' do
          let(:user) { create :registered_user }
          it 'raises error' do
            expect{ run_send_signup_email }.to raise_error(UsersController::UserAdminError)
          end
        end
      end

      context 'for unregistered user' do
        let(:user) { create :unregistered_user_with_valid_signup_token }
        let(:token) { 'some_token' }
        let(:dummy_mailer) { double(User).as_null_object }
        let(:sf_client) { double(SalesforceAPI) }

        before(:each) do
          allow(sf_client).to receive(:get_contact_signup_token).and_return(token)
          allow(SalesforceAPI).to receive(:client).and_return(sf_client)
        end

        context 'with a valid signup token' do
          it 'sends the email' do
            expect(SendSignupEmailMailer).to receive(:with)
              .with(email: user.email,
                    first_name: user.first_name,
                    sign_up_url: new_user_registration_url(signup_token: token, protocol: 'https')
              ).once.and_return(dummy_mailer)
            expect(dummy_mailer).to receive(:deliver_now).once
            run_send_signup_email
          end

          it 'redirects back to show_send_signup_email with success message' do
            allow(SendSignupEmailMailer).to receive(:with).and_return(dummy_mailer)
            run_send_signup_email
            expect(response).to redirect_to(user_path(user))
          end
        end

        context 'with an invalid signup token' do
          let(:user) { create :unregistered_user_with_invalid_signup_token }

          before(:each) do
            allow(sf_client).to receive(:update_contact)
          end

          it 'generates a new, valid signup token and sends an email' do
            invalid_token = user.signup_token
            run_send_signup_email
            expect(sf_client).to have_received(:update_contact)
            expect(user.reload.signup_token).not_to eq(invalid_token)
          end

          it 'sends the email' do
            expect(SendSignupEmailMailer).to receive(:with)
            .with(email: user.email,
                  first_name: user.first_name,
                  sign_up_url: new_user_registration_url(signup_token: token, protocol: 'https')
            ).once.and_return(dummy_mailer)
            expect(dummy_mailer).to receive(:deliver_now).once
            run_send_signup_email
          end

          it 'redirects back to user_path with success message' do
            allow(SendSignupEmailMailer).to receive(:with).and_return(dummy_mailer)
            run_send_signup_email
            expect(response).to redirect_to(user_path(user))
          end
        end
      end
    end

    describe "PUT #update" do
      # Oddly enough, the role_ids actually do come through with a single empty string in the array
      # when none are set.
      let(:valid_update_attributes) { valid_attributes.merge({ role_ids: [""]}) }

      it "returns a success response" do
        put :update, params: { id: user.to_param, user: valid_update_attributes }
        expect(response).to redirect_to(user_path(user))
      end
    end

    describe "POST #delete" do
      it "deletes the user" do
        expect {
          delete :destroy, params: { id: user.id }
        }.to change(User, :count).by(-1)
      end

      it "redirects to index" do
        delete :destroy, params: { id: user.id }
        expect(response).to redirect_to(users_path)
      end
    end
  end
end
