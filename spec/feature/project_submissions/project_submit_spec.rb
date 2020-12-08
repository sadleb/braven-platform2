require 'rails_helper'
require 'capybara_helper'

require 'lti_advantage_api'
require 'lti_score'

RSpec.feature 'Submit a project', :type => :feature do
  let(:course_project_version) { create :course_project_version }
  let(:section) { create :section, course: course_project_version.course }
  let(:user) { create :fellow_user, section: section }
  let(:project_submission) { create :project_submission, user: user, course_project_version: course_project_version }
  
  let!(:lti_launch) { 
    create(
      :lti_launch_assignment, 
      canvas_user_id: project_submission.user.canvas_user_id,
      course_id: project_submission.course_project_version.course.id,
    )
  }
  let(:uri) {
    path = Addressable::URI.parse(
      new_course_project_version_project_submission_path(
        project_submission.course_project_version,
      ),
    )
    # To let us bypass login using the state query parameter
    path.query = { state: lti_launch.state }.to_query
    path.to_s
  }
  let(:lti_advantage_access_token) { 
    FactoryBot.json(:lti_advantage_access_token)
  }

  before(:each) do
    # We need to ignore these hosts because VCR can't record AJAX requests
    lti = Addressable::URI.parse(lti_launch.request_message.line_item_url)

    VCR.configure do |c|
      c.ignore_localhost = true
      # Ignore AJAX requests to platformweb, xapi_assignment, Canvas LTI
      c.ignore_hosts Capybara.server_host, lti.host
    end

    # Stubs for interacting with Canvas for submissions
    allow_any_instance_of(LtiAdvantageAPI)
      .to receive(:get_access_token)
      .and_return(lti_advantage_access_token)
    allow_any_instance_of(LtiAdvantageAPI)
      .to receive(:create_score)
      .and_return({body: '{}'})
  end

  describe "creating a project submission" do
    xit "shows a submit button", js: true do
      # TODO: all tests commented out until https://github.com/bebraven/platform/pull/482 is merged.
      visit uri
      expect(page).to have_button('project-submit-button')
      expect(page).to have_button('Submit')
    end

    xit "shows a re-submit button", js: true do
      visit uri
      expect(page).to have_button('project-submit-button')
      expect(page).to have_button('Re-Submit')
    end

    xit "creates a new submission", js: true do
      visit uri
      click_button 'project-submit-button'

      expect(page).to have_selector('.alert')
      expect(page).to have_selector('.alert-success')
    end

    xit "updates button text after submission", js: true do
      visit uri
      click_button 'project-submit-button'

      # Wait for and close the alert
      expect(page).to have_selector('.alert')
      expect(page).to have_selector('.alert-success')
      find('button.close').click

      expect(page).to have_button('project-submit-button')
      expect(page).to have_button('Re-Submit')
    end
  end

  describe "invalid project submission" do
    context "with previous submission" do
      xit "still shows re-submit button text", js: true do

        # Generate an error when we're trying to create the submission
        allow_any_instance_of(LtiAdvantageAPI)
          .to receive(:create_score)
          .and_raise('failed to create another submission')

        # Suppress these so we can verify that the UI handles errors
        page.config.raise_server_errors = false

        visit uri

        expect(page).to have_button('Re-Submit')
        click_button 'project-submit-button'

        expect(page).to have_selector('.alert-warning')
        find('button.close').click

        expect(page).to have_button('project-submit-button')
        expect(page).to have_button('Re-Submit')
      end
    end

    context "no LTI state" do
      xit "shows an error", js: true do
        # Suppress these so we can verify that the UI handles errors
        page.config.raise_server_errors = false

        visit uri

        # Make the LTI state ID invalid
        # Capybara's fill_in doesn't work because the input is hidden
        page.execute_script(
          "document.querySelector('input[type=\"hidden\"][name=\"state\"]').value = 'invalidstate'"
        )
        click_button 'project-submit-button'

        expect(page).to have_selector('.alert-warning')
      end
    end
  end
end
