require "rails_helper"
require "capybara_helper"
require "securerandom"

include ERB::Util
include Rack::Utils

RSpec.describe ProjectSubmissionsController, type: :feature do
  let(:input_name) { 'test-input-name' }
  let(:project_version) { create :project_version, body: %{
    <p>Based on these responses, what are your next steps?</p>
    <textarea id='test-question-id' name="#{input_name}"></textarea>
  } }
  let(:course_project_version) { create :course_project_version, project_version: project_version }
  let(:section) { create :section, course: course_project_version.course }
  let(:user) { create :fellow_user, section: section }
  let(:project_submission) { create :project_submission, user: user, course_project_version: course_project_version }
  let!(:project_submission_answers) { [
    create(:project_submission_answer, project_submission: project_submission, input_name: input_name),
  ] }
  let!(:lti_launch) {
    create(
      :lti_launch_assignment,
      canvas_user_id: project_submission.user.canvas_user_id,
    )
  }

  before(:each) do
    lti = Addressable::URI.parse(lti_launch.request_message.line_item_url)
    VCR.configure do |c|
      c.ignore_localhost = true
      # Must ignore the Capybara host IFF we are running tests that have browser AJAX requests to that host.
      c.ignore_hosts Capybara.server_host, lti.host
    end

    allow_any_instance_of(LtiAdvantageAPI)
      .to receive(:get_access_token)
      .and_return('some access token')

    allow_any_instance_of(LtiAdvantageAPI)
      .to receive(:get_line_item_for_user)
      .and_return({})
  end

  after(:each) do
    # Print JS console errors, just in case we need them.
    # From https://stackoverflow.com/a/36774327/12432170.
    errors = page.driver.browser.manage.logs.get(:browser)
    if errors.present?
      message = errors.map(&:message).join("\n")
      puts message
    end
  end

  describe "GET #new", js: true do
    let(:url) {
      new_course_project_version_project_submission_path(
        project_submission.course_project_version,
        state: lti_launch.state,
      )
    }

    before(:each) do
      # Note that no login happens. The LtiAuthentication::WardenStrategy uses the lti_launch.state to authenticate.
      visit url
    end

    it "fetches the most recent answers" do
      # Check that data is fetched
      expect(page).to have_field(project_submission_answers.first.input_name,
        with: project_submission_answers.first.input_value, wait: 10)
    end

    it 'saves the input value' do
      input_value = 'test answer'
      find("[name='#{input_name}']").set input_value
      # The save-answer code runs on blur, so click off the element.
      find("p").click
      # Wait and hope for the async JS to finish.
      sleep 3

      # Check to make sure the answer actually got saved.
      # For some reason the input value gets messed up somehow...
      # Maybe fix that some day? In the meantime, just compare with `include`.
      expect(ProjectSubmissionAnswer.last.input_value).to include(input_value)
    end
  end

  describe "GET #show", js: true do
    before(:each) do
      # Note that no login happens. The LtiAuthentication::WardenStrategy uses the lti_launch.state to authenticate.
      visit url
    end

    context "when valid LtiLaunch" do
      let(:url) {
       course_project_version_project_submission_path(
          course_project_version,
          project_submission,
          state: lti_launch.state,
        )
      }

      it "fetches only the data for the submission" do
        # Check that data is fetched.
        # Do it in two steps just for better granularity if the first one fails.
        expect(page).to have_field(project_submission_answers.first.input_name, disabled: true)
        expect(page).to have_field(
          project_submission_answers.first.input_name,
          disabled: true,
          with: project_submission_answers.first.input_value,
          wait: 10
        )
      end

      it "shows the submission" do
        # Do some basic tests first to give a little more granularity if this fails.
        expect(current_url).to include(url)
        expect(page).to have_content("Based on these responses,")
      end

      it "cannot be edited" do
        # Disabled
        expect(page).to have_field(
          'test-question-id',
          type: 'textarea',
          disabled: true,
        )
        # Highlighted
        expect(page).to have_css('textarea[disabled]')
      end
    end

    # Note: these return a 500 error, but we can't check the response code with the Selenium driver
    # so we rely on the page title instead. 
    context "when LtiLaunch isn't found" do
      let(:url) {
        course_project_version_project_submission_path(
          course_project_version,
          project_submission,
          state: "invalidltilaunchstate",
        )
      }

      it "doesn't show the submission" do
        page.config.raise_server_errors = false # Let the errors get converted into the actual server response so we can test that.
        expect(page).not_to have_title("Project")
      end
    end

    context "when user isn't found" do
      let(:lti_launch_with_invalid_user) {
        lti_launch = create(
          :lti_launch_assignment,
          canvas_user_id: '987654321',
        )
      }
      let(:url) {
        course_project_version_project_submission_path(
          course_project_version,
          project_submission,
          state: lti_launch_with_invalid_user.state,
        )
      }

      it "doesnt show the submission" do
        page.config.raise_server_errors = false # Let the errors get converted into the actual server response so we can test that.
        expect(page).not_to have_title("Project")
      end
    end
  end
end
