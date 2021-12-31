require 'rails_helper'
require 'salesforce_api'

RSpec.describe Users::RegistrationsController, type: :controller do
  render_views

  describe '#show' do
    subject { get :show, params: { uuid: uuid } }

    context 'with invalid uuid param' do
      let(:uuid) { 'invalid uuid' }

      it 'shows uuid param in hidden field' do
        # Act like the uuid is valid, for security purposes.
        subject
        expect(response.body).to include("<input value=\"#{uuid}\" type=\"hidden\" name=\"user[uuid]\"")
      end
    end

    context 'with valid uuid param' do
      let(:user) { create(:registered_user) }
      let(:uuid) { user.uuid }

      it 'shows uuid param in hidden field' do
        subject
        expect(response.body).to include("<input value=\"#{uuid}\" type=\"hidden\" name=\"user[uuid]\"")
      end
    end
  end

  describe '#new' do
    subject { get :new, params: params }

    context 'with no tokens' do
      let(:params) { {} }

      it 'renders bad_link' do
        subject
        expect(response.body).to include("Uh oh. Something went wrong!")
      end
    end

    context 'with empty signup_token' do
      let(:params) { {
        signup_token: '',
      } }

      it 'renders bad_link' do
        subject
        expect(response.body).to include("Uh oh. Something went wrong!")
      end
    end

    context 'with empty reset_password_token' do
      let(:params) { {
        reset_password_token: '',
      } }

      it 'renders bad_link' do
        subject
        expect(response.body).to include("Uh oh. Something went wrong!")
      end
    end

    context 'with invalid signup_token' do
      let(:params) { {
        signup_token: 'invalid token',
      } }

      it 'renders form' do
        # Act like the token is valid, for security purposes.
        subject
        expect(response.body).to include("<h1>Create Account</h1>")
        expect(response.body).to include("<form action=\"#{user_registration_path}\"")
        expect(response.body).to include("<input value=\"#{params[:signup_token]}\" type=\"hidden\" name=\"user[signup_token]\"")
      end
    end

    context 'with invalid reset_password_token' do
      let(:params) { {
        reset_password_token: 'invalid token',
      } }

      it 'renders form' do
        # Act like the token is valid, for security purposes.
        subject
        expect(response.body).to include("<h1>Create Account</h1>")
        expect(response.body).to include("<form action=\"#{user_registration_path}\"")
        expect(response.body).to include("<input value=\"#{params[:reset_password_token]}\" type=\"hidden\" name=\"user[reset_password_token]\"")
      end
    end

    context 'with valid signup_token, registered user' do
      let(:user) { create(:registered_user) }
      let(:params) { {} }

      before :each do
        params[:signup_token] = user.set_signup_token!
      end

      it 'redirects to login' do
        subject
        expect(response).to redirect_to(/#{cas_login_path}/)
      end
    end

    context 'with valid reset_password_token, registered user' do
      let(:user) { create(:registered_user) }
      let(:params) { {} }

      before :each do
        params[:reset_password_token] = user.send(:set_reset_password_token)
      end

      it 'redirects to login' do
        subject
        expect(response).to redirect_to(/#{cas_login_path}/)
      end
    end

    context 'with valid signup_token, unregistered user' do
      let(:user) { create(:unregistered_user) }
      let(:params) { {} }

      before :each do
        params[:signup_token] = user.set_signup_token!
      end

      it 'renders form' do
        subject
        expect(response.body).to include("<h1>Create Account</h1>")
        expect(response.body).to include("<form action=\"#{user_registration_path}\"")
        expect(response.body).to include("<input value=\"#{params[:signup_token]}\" type=\"hidden\" name=\"user[signup_token]\"")
      end
    end

    context 'with valid reset_password_token, unregistered user' do
      let(:user) { create(:unregistered_user) }
      let(:params) { {} }

      before :each do
        params[:reset_password_token] = user.send(:set_reset_password_token)
      end

      it 'renders form' do
        subject
        expect(response.body).to include("<h1>Create Account</h1>")
        expect(response.body).to include("<form action=\"#{user_registration_path}\"")
        expect(response.body).to include("<input value=\"#{params[:reset_password_token]}\" type=\"hidden\" name=\"user[reset_password_token]\"")
      end
    end
  end

  describe '#create' do
    let(:password_value) { 'Val!dPassw0rd' }
    subject { post :create, params: params }

    let(:sf_client) { double(SalesforceAPI,
      find_participants_by_contact_id: [SalesforceAPI::SFParticipant.new(user.first_name, user.last_name, user.email)],
      find_program: SalesforceAPI::SFProgram.new,
    ) }
    let(:service) { double(RegisterUserAccount, run: nil) }

    context 'with no tokens' do
      let(:params) { {
        'user[password]': password_value,
        'user[password_confirmation]': password_value,
      } }

      it 'renders bad_link' do
        subject
        expect(response.body).to include("Uh oh. Something went wrong!")
      end
    end

    context 'with empty signup_token' do
      let(:params) { {
        'user[password]': password_value,
        'user[password_confirmation]': password_value,
        'user[signup_token]': '',
      } }

      it 'renders bad_link' do
        subject
        expect(response.body).to include("Uh oh. Something went wrong!")
      end
    end

    context 'with empty reset_password_token' do
      let(:params) { {
        'user[password]': password_value,
        'user[password_confirmation]': password_value,
        'user[reset_password_token]': '',
      } }

      it 'renders bad_link' do
        subject
        expect(response.body).to include("Uh oh. Something went wrong!")
      end
    end

    context 'with invalid signup_token' do
      let(:params) { {
        'user[password]': password_value,
        'user[password_confirmation]': password_value,
        'user[signup_token]': 'invalid token',
      } }

      it 'renders bad_link' do
        subject
        expect(response.body).to include("Uh oh. Something went wrong!")
      end
    end

    context 'with invalid reset_password_token' do
      let(:params) { {
        'user[password]': password_value,
        'user[password_confirmation]': password_value,
        'user[reset_password_token]': 'invalid token',
      } }

      it 'renders bad_link' do
        subject
        expect(response.body).to include("Uh oh. Something went wrong!")
      end
    end

    context 'with expired signup_token' do
      let(:user) { create(:unregistered_user) }
      let(:params) { {
        'user[password]': password_value,
        'user[password_confirmation]': password_value,
      } }

      before :each do
        allow(SalesforceAPI).to receive(:client).and_return(sf_client)
        params['user[signup_token]'] = user.set_signup_token!
        user.update!(signup_token_sent_at: 5.weeks.ago)
      end

      it 'renders bad_link' do
        # Don't reveal why the token is invalid, for security purposes.
        subject
        expect(response.body).to include("Uh oh. Something went wrong!")
      end
    end

    context 'with expired reset_password_token' do
      let(:user) { create(:unregistered_user) }
      let(:params) { {
        'user[password]': password_value,
        'user[password_confirmation]': password_value,
      } }

      before :each do
        allow(SalesforceAPI).to receive(:client).and_return(sf_client)
        params['user[reset_password_token]'] = user.send(:set_reset_password_token)
        user.update!(reset_password_sent_at: 5.days.ago)
      end

      it 'renders bad_link' do
        # Don't reveal why the token is invalid, for security purposes.
        subject
        expect(response.body).to include("Uh oh. Something went wrong!")
      end
    end

    context 'with valid signup_token, registered user' do
      let(:user) { create(:registered_user) }
      let(:params) { {
        'user[password]': password_value,
        'user[password_confirmation]': password_value,
      } }

      before :each do
        allow(service).to receive(:create_canvas_user!)
        allow(SalesforceAPI).to receive(:client).and_return(sf_client)
        allow(RegisterUserAccount).to receive(:new).and_return(service)
        params['user[signup_token]'] = user.set_signup_token!
      end

      it 'redirects to login' do
        subject
        expect(response).to redirect_to(/#{cas_login_path}/)
      end
    end

    context 'with valid reset_password_token, registered user' do
      let(:user) { create(:registered_user) }
      let(:params) { {
        'user[password]': password_value,
        'user[password_confirmation]': password_value,
      } }

      before :each do
        allow(SalesforceAPI).to receive(:client).and_return(sf_client)
        params['user[reset_password_token]'] = user.send(:set_reset_password_token)
      end

      it 'redirects to login' do
        subject
        expect(response).to redirect_to(/#{cas_login_path}/)
      end
    end

    context 'with valid signup_token, unregistered user, register works' do
      let(:user) { create(:unregistered_user) }
      let(:params) { {
        'user[password]': password_value,
        'user[password_confirmation]': password_value,
      } }

      before :each do
        allow(RegisterUserAccount).to receive(:new).and_return(service)
        params['user[signup_token]'] = user.set_signup_token!
      end

      it 'runs register service' do
        subject
        expect(service).to have_received(:run).once
      end

      it 'redirects to #show with uuid' do
        subject
        expect(response).to redirect_to(users_registration_path(uuid: user.uuid))
      end
    end

    context 'with valid signup_token, unregistered user, user validation fails' do
      let(:user) { create(:unregistered_user) }
      let(:updated_user) { create(:unregistered_user) }
      let(:params) { {
        'user[password]': password_value,
        'user[password_confirmation]': password_value,
      } }

      before :each do
        # Since the service is stubbed, user.update! is never called. We just manually
        # create one with errors.
        updated_user.errors.add(:email, :empty)
        allow(service).to receive(:run).and_yield(updated_user)
        allow(RegisterUserAccount).to receive(:new).and_return(service)
        params['user[signup_token]'] = user.set_signup_token!
      end

      it 'renders form' do
        subject
        expect(response.body).to include("<h1>Create Account</h1>")
        expect(response.body).to include("<form action=\"#{user_registration_path}\"")
        expect(response.body).to include("<input value=\"#{params['user[signup_token]']}\" type=\"hidden\" name=\"user[signup_token]\"")
      end

      it 'renders errors' do
        subject
        expect(response.body).to include("Please try again")
        expect(response.body).to include("<div id=\"error_explanation\">")
      end

      context 'with weak password' do
        let(:password_value) { 'password' }
        it 'shows that error message' do
          updated_user.errors.delete(:email)
          updated_user.errors.add(:password, :not_complex)
          subject
          expect(response.body).to include("Password requires")
        end
      end
    end

    context 'with valid reset_password_token, unregistered user, register works' do
      let(:user) { create(:unregistered_user) }
      let(:params) { {
        'user[password]': password_value,
        'user[password_confirmation]': password_value,
      } }

      before :each do
        allow(RegisterUserAccount).to receive(:new).and_return(service)
        params['user[reset_password_token]'] = user.send(:set_reset_password_token)
      end

      it 'runs register service' do
        subject
        expect(service).to have_received(:run).once
      end

      it 'redirects to #show with uuid' do
        subject
        expect(response).to redirect_to(users_registration_path(uuid: user.uuid))
      end
    end
  end
end
