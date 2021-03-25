require "rails_helper"
require "capybara_helper"

include ERB::Util
include Rack::Utils

RSpec.describe CasController, type: :routing do
  let!(:valid_user) { create(:registered_user) }
  let(:valid_user_creds) {{ email: valid_user.email, password: valid_user.password }}
  let(:invalid_user_creds) {{ email: 'bad_user', password: 'bad_pass' }}

  describe "/cas/login without service url" do
    before(:each) do
      visit "/cas/login"
      fill_and_submit_login(username, password)
    end

    context "when username and password are valid" do
      let(:username) { valid_user_creds[:email] }
      let(:password) { valid_user_creds[:password] }

      it "logs in successfully" do
        # Ensure that the login was successful
        expect(page).to have_content("You have successfully logged in")
      end
    end

    context "when username and password are invalid" do
      let(:username) { invalid_user_creds[:email] }
      let(:password) { invalid_user_creds[:password] }

      it "fails to log in" do
        # Ensure that the login was failed
        expect(page).to have_content("Incorrect username or password")
      end
    end
  end

  describe "/cas/login with service url" do
    let(:return_service) { 'http://braven/cas/login' }

    subject do
      VCR.use_cassette("sso_ticket_invalid", :match_requests_on => [:path]) do
        visit "/cas/login?service=#{url_encode(return_service)}"
        fill_and_submit_login(username, password)
      end
    end

    context "when username and password are valid" do
      let(:username) { valid_user_creds[:email] }
      let(:password) { valid_user_creds[:password] }

      it "logs in successfully" do
        subject
        # Ensure that the login was successful
        expect(current_url).to include(return_service)
        expect(current_url).to include("ticket")
      end

      it "validates existing tickets" do
        subject
        @params = parse_query(current_url, "&?,")
        expect(@params).to include("ticket")
      end

      it "generates new ticket when revisiting login page" do
        subject
        VCR.use_cassette("sso_ticket_invalid", :match_requests_on => [:path]) do
          # Get current ticket to check against next generated ticket
          @params = parse_query(current_url, "&?,")
          visit "/cas/login?service=#{url_encode(return_service)}"

          # New ticket should be generated
          expect(current_url).not_to include(@params["ticket"])
        end
      end
    end

    context "when user hasn't confirmed their email" do
      let!(:unconfirmed_user) { create(:unconfirmed_user) }
      let(:username) { unconfirmed_user.email }
      let(:password) { unconfirmed_user.password }

      it 'redirects to registration page with confirmation instructions' do
        subject
        expect(current_url).to match(
          /#{Regexp.escape("/users/registration?login_attempt=true&u=#{unconfirmed_user.salesforce_id}")}/
        )
        expect(status_code).to eq(200)
        expect(page).to have_content("Didn't receive email instructions")
        expect(find('h1').text).to eq('Please confirm your email address')
      end
    end
  end

  # These specs are for the situation where you try to go to the
  # /users/sign_up?u=blah endpoint when you've already signed up.
  # It redirects to login with the 'u' param, but the behavior is
  # slightly different than the normal login where you have to type
  # in your email.
  describe 'GET /cas/login with "u" param' do
    let(:password) { valid_user.password }

    subject do
      visit "/cas/login?u=#{valid_user.salesforce_id}&notice=Looks+like+you+have+already+signed+up"
    end

    it 'shows the message about having already signed up' do
      subject
      expect(page).to have_content('Looks like you have already signed up')
    end

    it 'only shows the password field' do
      subject
      expect(page).to have_css('input[type=password][autofocus]')
      expect(page).not_to have_css('input[type=text]')
      expect(page).not_to have_css('input[type=email]')
    end

    it 'has the hidden "u" field' do
      subject
      expect(find('input[type=hidden]#u', :visible => false).value).to eq(valid_user.salesforce_id)
    end
  end

  describe 'POST /cas/login with "u" param' do
    let(:password) { valid_user.password }

    subject do
      visit "/cas/login?u=#{valid_user.salesforce_id}&notice=Looks+like+you+have+already+signed+up"
      fill_and_submit_password(password)
    end

    it 'logs you in with just a password' do
      subject
      expect(page).to have_content('You have successfully logged in')
    end

    context "when user hasn't confirmed their email" do
      let!(:unconfirmed_user) { create(:unconfirmed_user) }
      let(:valid_user) { unconfirmed_user }

      it 'redirects to registration page with confirmation instructions' do
        subject
        expect(current_url).to match(
          /#{Regexp.escape("/users/registration?login_attempt=true&u=#{unconfirmed_user.salesforce_id}")}/
        )
        expect(status_code).to eq(200)
        expect(page).to have_content("Didn't receive email instructions")
        expect(find('h1').text).to eq('Please confirm your email address')
      end
    end
  end

end
