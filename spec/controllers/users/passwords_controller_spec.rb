require 'rails_helper'

RSpec.describe Users::PasswordsController, type: :controller do
  render_views

  describe '#edit' do
    subject { get :edit, params: { reset_password_token: @reset_password_token } }

    context 'with invalid token' do
      before :each do
        @reset_password_token = 'fake'
      end

      it 'shows the form' do
        # Act like the token is valid, for security purposes.
        subject
        expect(response.body).to include("Enter the password you'll use to")
      end
    end

    context 'with registered user, valid token' do
      let(:user) { create(:registered_user) }

      before :each do
        @reset_password_token = user.send(:set_reset_password_token)
      end

      it 'shows the form' do
        subject
        expect(response.body).to include("Enter the password you'll use to")
      end
    end

    context 'with unregistered user, valid token' do
      let(:user) { create(:unregistered_user) }

      before :each do
        @reset_password_token = user.send(:set_reset_password_token)
      end

      it 'redirects to registration with same token' do
        subject
        expect(response).to redirect_to(new_user_registration_path(reset_password_token: @reset_password_token))
      end
    end
  end

  describe '#update' do
    let(:password_value) { 'Val!dPassw0rd' }
    subject { post :update, params: {
      'user[reset_password_token]': @reset_password_token,
      'user[password]': password_value,
      'user[password_confirmation]': password_value,
    } }

    context 'with valid token' do
      let(:user) { create(:registered_user) }

      before :each do
        @reset_password_token = user.send(:set_reset_password_token)
      end

      it 'resets signup token' do
        # Reset signup_token, for security reasons.
        user.set_signup_token!
        expect(user.signup_token).not_to eq(nil)
        expect(user.signup_token_sent_at).not_to eq(nil)

        subject
        user.reload
        expect(user.signup_token).to eq(nil)
        # We always keep the sent_at value to determine whether initially we've successfully
        # created a new user to the point that they can sign up.
        expect(user.signup_token_sent_at).not_to eq(nil)
      end

      it 'redirects to log in page' do
        subject
        expect(response.status).to eq(302)
        expect(response.location).to match(/#{Regexp.escape(cas_login_url)}?.*notice=Password reset successfully/)
      end

      it 'does not log you in' do
        subject
        expect(controller.current_user).to eq(nil)
      end

      context 'with weak password' do
        let(:password_value) { 'password' }
        it 'shows that error message' do
          subject
          expect(response.body).to include("<div id=\"error_explanation\">")
          expect(response.body).to include("Password is too weak")
        end
      end
    end
  end
end
