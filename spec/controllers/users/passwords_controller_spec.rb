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
    subject { post :update, params: {
      'user[reset_password_token]': @reset_password_token,
      'user[password]': 'password',
      'user[password_confirmation]': 'password',
    } }

    context 'with valid token' do
      let(:user) { create(:registered_user) }

      before :each do
        @reset_password_token = user.send(:set_reset_password_token)
      end

      it 'resets signup token/sent_at' do
        # Reset both tokens, for security reasons.
        user.set_signup_token!
        expect(user.signup_token).not_to eq(nil)
        expect(user.signup_token_sent_at).not_to eq(nil)

        subject
        user.reload
        expect(user.signup_token).to eq(nil)
        expect(user.signup_token_sent_at).to eq(nil)
      end
    end
  end
end
