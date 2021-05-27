require "rails_helper"
require "capybara_helper"

include ERB::Util
include Rack::Utils

RSpec.describe CasController, type: :routing do
  let!(:valid_user) { create(:registered_user) }
  let(:valid_user_creds) {{ email: valid_user.email, password: valid_user.password }}
  let(:invalid_user_creds) {{ email: 'bad_user', password: 'bad_pass' }}

  describe "/cas/login with service url" do
    let(:return_service) { 'http://braven/cas/login' }

    subject do
      VCR.use_cassette("sso_ticket_invalid", :match_requests_on => [:path]) do
        visit "/cas/login?service=#{url_encode(return_service)}"
        fill_and_submit_login(username, password)
      end
    end

    shared_examples "login with service_url" do
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

      context 'for registered user' do
        let!(:valid_user) { create(:registered_user) }
        it_behaves_like 'login with service_url'
      end

      context 'for user needed reconfirmation of new email' do
        let!(:valid_user) { create(:reconfirmation_user) }
        it_behaves_like 'login with service_url'
      end
    end

    shared_examples 'unconfirmed user' do
      # Make sure and set both the unconfirmed_user and username before running this.

      context "when using correct password" do
        let(:password) { unconfirmed_user.password }

        it 'redirects to registration page with confirmation instructions' do
          subject
          expect(current_url).to match(
            /#{Regexp.escape("/users/registration?login_attempt=true&uuid=#{unconfirmed_user.uuid}")}/
          )
          expect(status_code).to eq(200)
          expect(page).to have_content("Didn't receive email instructions")
          expect(find('h1').text).to eq('Please confirm your email address')
        end
      end

      context "using incorrect password" do
        let(:password) { 'NotTheRightPassword' }

        it "fails to log in" do
          subject
          # Ensure that the login was failed and don't expose any information about the state of the
          # confirmation for security purposes.
          expect(page).to have_content("Incorrect username or password")
        end
      end
    end

    context "when user hasn't confirmed their existing email" do
      let!(:unconfirmed_user) { create(:unconfirmed_user) }
      let(:username) { unconfirmed_user.email }
      it_behaves_like 'unconfirmed user'
    end

    context "when user hasn't confirmed their new email and tries to log in with it" do
      let!(:unconfirmed_user) { create(:reconfirmation_user) }
      let(:username) { unconfirmed_user.unconfirmed_email }
      it_behaves_like 'unconfirmed user'
    end

  end

end
