require 'rails_helper'
require 'capybara_helper'

require 'linked_in_api'

RSpec.feature 'Authorize LinkedIn access to user data', :type => :feature do
  let(:canvas_user_id) { 1717 }
  let(:section) { create(:section) }
  let!(:user) { create :linked_in_user, canvas_user_id: canvas_user_id, section: section }
  let!(:lti_launch) { create( :lti_launch_assignment, canvas_user_id: canvas_user_id) }
  let(:linkedin_project) { create(:linkedin_project) }
  let(:linkedin_project_version) { create(:project_version, body: linkedin_project.body, custom_content: linkedin_project) }
  # There's no way to set the referer header in selenium, so instead we
  # create a project with a real linkedin button iframe, and that sets a
  # real referer header. Most of these `let`s are to support that.
  let(:course_project_version) { create(:course_project_version, course: section.course, custom_content_version: linkedin_project_version) }

  describe "visit the signin page", js: true do
    before(:each) do
      VCR.configure do |c|
        c.ignore_localhost = true
        c.ignore_hosts Capybara.server_host
      end
    end

    context "signin" do
      let(:path) {
        new_course_project_version_project_submission_path(
          course_project_version_id: course_project_version.id,
          state: lti_launch.state,
        )
      }

      before :each do
        # Note that no login happens. The LtiAuthentication::WardenStrategy uses the lti_launch.state to authenticate.
        visit path
      end

      it "renders the LinkedIn sign-in link", js: true do
        within_frame(0) {
          expect(page).to have_selector('#linked-in-login')
        }
      end

      it "sign-in link opens a new window", js: true, ci_exclude: true do
        # Click link
        popup = window_opened_by { within_frame(0) { find('#linked-in-login').click } }
 
        # Check pop-up
        within_window popup do
          expect(current_url).to include('https://www.linkedin.com/')

          # Note: this page title is specified by LinkedIn, if it changes
          # this test will fail until we update the string.
          # We only check that the title ends to "| LinkedIn" because it can
          # vary depending on whether the test runs on an endpoint that's
          # whitelisted by Braven's LinkedIn app. 
          expect(page.title).to match(/| LinkedIn$/)
        end
      end
    end

    context "launch" do
      let(:path) { linked_in_auth_path(state: lti_launch.state) }

      before :each do
        # Note that no login happens. The LtiAuthentication::WardenStrategy uses the lti_launch.state to authenticate.
        visit path
      end

      it "redirects to the LinkedIn", js: true, ci_exclude: true do
          expect(current_url).to include('https://www.linkedin.com/')
          expect(page.title).to match(/| LinkedIn$/)
      end
    end
  end
end
