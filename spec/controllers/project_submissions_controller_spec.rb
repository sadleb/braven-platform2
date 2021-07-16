require 'rails_helper'
require 'lti_score'

RSpec.describe ProjectSubmissionsController, type: :controller do
  render_views

  let(:course_project_version) { create :course_project_version }
  let(:section) { create :section, course: course_project_version.course }
  let(:user_who_submitted) { create :fellow_user, section: section }
  let(:user_viewing_submission) { user_who_submitted }
  let(:project_submission) {
    create :project_submission, user: user_who_submitted, course_project_version: course_project_version
  }
  let(:lti_launch) {
    create :lti_launch_assignment, canvas_user_id: user_viewing_submission.canvas_user_id
  }

  describe 'GET #show' do

    before(:each) do
      allow(LtiLaunch).to receive(:current).and_return(lti_launch)
      get(
        :show,
        params: {
          course_project_version_id: project_submission.course_project_version.id,
          id: project_submission.id,
          type: 'CourseProjectVersion',
          state: lti_launch.state,
        }
      )
    end

    shared_examples 'a successful request' do
      scenario 'returns a success response' do
        expect(response).to be_successful
      end

      scenario 'shows the correct content' do
        expect(response.body.include?(course_project_version.project_version.body)).to be(true)
      end
    end

    context "as a Fellow" do
      it_behaves_like 'a successful request'
    end

    context "as a TA" do
      let(:ta_section) { create :ta_section, course: course_project_version.course }
      let(:ta_user) { create :ta_user, section: ta_section }
      let(:user_viewing_submission) { ta_user }

      it_behaves_like 'a successful request'
    end

    context "as an LC" do
      let(:lc_user) { create :ta_user, section: section }
      let(:user_viewing_submission) { lc_user }

      it_behaves_like 'a successful request'
    end

  end # 'GET #show'

  describe 'GET #new' do
    subject(:new_request) do
      allow(LtiLaunch).to receive(:current).and_return(lti_launch)
      get(
        :new,
        params: {
          course_project_version_id: course_project_version.id,
          type: 'CourseProjectVersion',
          state: lti_launch.state,
        }
      )
    end

    context 'first time viewing submission' do

      it 'creates an unsubmited project_submission to work on' do
        expect{ new_request }.to change { ProjectSubmission.count }.by(1)
        expect(ProjectSubmission.last.is_submitted).to be(false)
      end

      it 'redirects to edit' do
        new_request
        # Have to use `assigns` here because we don't want to create the submission
        # in order to get the path. Instead, just bind to the submission created by
        # the controller to construct the path.
        expect(response).to redirect_to :action => :edit,
          :id => assigns(:project_submission).id, :state => lti_launch.state
      end

    end

    context 'returning to submission later' do

      it 'does not create a new submission' do
        project_submission # create it first
        expect{ new_request }.not_to change { ProjectSubmission.count }
      end

      it 'redirects to edit' do
        # Note: creates the unsubmitted project_submission
        edit_path = edit_course_project_version_project_submission_path(
          course_project_version,
          project_submission,
          state: lti_launch.state
        )

        new_request

        expect(response).to redirect_to(edit_path)
      end

    end
  end # 'GET #new'

  describe 'GET #edit' do

    subject(:edit_request) do
      allow(LtiLaunch).to receive(:current).and_return(lti_launch)
      get(
        :edit,
        params: {
          course_project_version_id: project_submission.course_project_version.id,
          id: project_submission.id,
          type: 'CourseProjectVersion',
          state: lti_launch.state,
        }
      )
    end

    it 'returns a success response' do
      edit_request
      expect(response).to be_successful
    end

    it 'shows the correct content' do
      edit_request
      expect(response.body.include?(course_project_version.project_version.body)).to be(true)
    end

    it 'fails for submitted project' do
      project_submission.update!(is_submitted: true)
      edit_request
      expect(response).to have_http_status(403)
      expect(response.body).to match /Permission Denied/
    end

  end


  describe 'POST #submit' do

    it 'creates a submission' do
      allow_any_instance_of(LtiAdvantageAPI)
        .to receive(:get_access_token)
        .and_return('oasjfoasjofdj')

      stub_request(:post, "#{lti_launch.request_message.line_item_url}/scores").to_return(body: '{"fake" : "response"}')

      # Create an unsubmitted one to work on
      project_submission

      expect {
        post(
          :submit,
          params: {
            course_project_version_id: course_project_version.id,
            type: 'CourseProjectVersion',
            state: lti_launch.state,
          },
        )
      }.to change {ProjectSubmission.count}.by(1)

      ps = ProjectSubmission.where(course_custom_content_version_id: course_project_version.id, is_submitted: true).first
      submission_url = course_project_version_project_submission_url(
        course_project_version, ps, protocol: 'https'
      )

      expect(WebMock)
        .to have_requested(
          :post,
          "#{lti_launch.request_message.line_item_url}/scores",
        )
        .with { |req|
          body = JSON.parse(req.body)
          return false if user_who_submitted.canvas_user_id.to_s != body['userId'].to_s
          submission_url == body[LtiScore::LTI_SCORE_SUBMISSION_URL_KEY]['submission_data']
        }
        .once
    end
  end
end
