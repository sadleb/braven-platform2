require 'rails_helper'
require 'linked_in_api'

RSpec.describe LinkedInAuthorizationController, type: :controller do
  render_views
  let(:user) { create :fellow_user }
  let(:valid_session) { {} }
  let(:target_link_uri) { 'https://target/link' }
  let(:state) { LtiLaunchController.generate_state }
  let(:lti_launch) { create(:lti_launch_assignment_selection, target_link_uri: target_link_uri, state: state) }

  before do
    sign_in user
  end
  
  describe 'GET #login' do
    before :each do
      request.headers['Referer'] = "https://example.org/?state=#{lti_launch.state}"
    end

    it 'returns a success response' do
      get :login, session: valid_session
      expect(response).to be_successful
    end
  end

  describe 'GET #launch' do
    before(:each) do
      allow(LinkedInAPI)
        .to receive(:authorize_url)
        .and_return('')
    end

    it 'returns a success response' do
      get :launch, session: valid_session
      expect(response).to be_successful
    end

    # Note: We test the redirect in a feature spec because it is handled by 
    # the React component and not by the controller. 
    it 'gets LinkedIn authorization url' do
      expect(LinkedInAPI).to receive(:authorize_url)
      get :launch, session: valid_session
    end
  end

  describe 'GET #redirect' do
    before(:each) do
      allow(LinkedInAPI)
      .to receive(:exchange_code_for_token)
      .and_return('some-access-token')
    end

    it 'returns a success response' do
      # Generate a random number to use as the CSRF token
      user.linked_in_state = rand().to_s
      user.save!
      get(
        :oauth_redirect,
        params: { state: user.linked_in_state, code: 'some-auth-code' },
        session: valid_session,
      )
      expect(response).to be_successful
      expect(user.reload.linked_in_access_token).to eq('some-access-token')
      expect(user.reload.linked_in_authorized_at).not_to eq(nil)
      expect(user.reload.linked_in_state).to be_empty
    end

    it "throws an error if state doesn't match" do
      expect {
        get(
          :oauth_redirect,
          params: { state: 'not-a-real-csrf-token', code: 'some-auth-code' },
          session: valid_session,
        )
      }
      .to raise_error(SecurityError)
      expect(user.reload.linked_in_state).to be_empty
    end
  end
end
