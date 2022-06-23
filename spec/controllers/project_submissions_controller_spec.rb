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

  before :each do
    sign_in user_viewing_submission
    allow(LtiLaunch).to receive(:from_id)
      .with(user_viewing_submission, lti_launch.id)
      .and_return(lti_launch)
  end

  describe 'GET #show' do

    before(:each) do
      get(
        :show,
        params: {
          course_project_version_id: project_submission.course_project_version.id,
          id: project_submission.id,
          type: 'CourseProjectVersion',
          lti_launch_id: lti_launch.id,
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
      let(:ta_user) { create :ta_user, accelerator_section: ta_section }
      let(:user_viewing_submission) { ta_user }

      it_behaves_like 'a successful request'
    end

    context "as an LC" do
      let(:lc_user) { create :ta_user, accelerator_section: section }
      let(:user_viewing_submission) { lc_user }

      it_behaves_like 'a successful request'
    end

  end # 'GET #show'

  describe 'GET #new' do
    subject(:new_request) do
      get(
        :new,
        params: {
          course_project_version_id: course_project_version.id,
          type: 'CourseProjectVersion',
          lti_launch_id: lti_launch.id,
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
          :id => assigns(:project_submission).id, :lti_launch_id => lti_launch.id
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
          lti_launch_id: lti_launch.id
        )

        new_request

        expect(response).to redirect_to(edit_path)
      end

    end
  end # 'GET #new'

  describe 'GET #edit' do
    let!(:program) { build :heroku_connect_program,
      canvas_cloud_accelerator_course_id__c: lti_launch.course_id,
      grades_finalized_date__c: Time.now.utc.to_date
    }
    let!(:participant) { build :heroku_connect_fellow_participant,
      grades_finalized_extension__c: Time.now.utc.to_date
    }

    subject(:edit_request) do
      get(
        :edit,
        params: {
          course_project_version_id: project_submission.course_project_version.id,
          id: project_submission.id,
          type: 'CourseProjectVersion',
          lti_launch_id: lti_launch.id,
        }
      )
    end

    before(:each) do
      allow(HerokuConnect::Program).to receive(:find_by).and_return(program)
      allow(HerokuConnect::Participant).to receive(:find_participant).and_return(participant)
      allow(Honeycomb).to receive(:add_support_alert)
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

    context 'when no HerokuConnect::Program is found for the course' do
      let!(:program) { nil }
      it 'sends Honeycomb alert' do
        edit_request
        expect(Honeycomb).to have_received(:add_support_alert).once
      end

      it 'launches the project in normal edit mode with a submit button' do
        edit_request
        expect(response.body).to include('data-read-only="false"')
        expect(response.body).to include('<div data-react-class="Projects/ProjectSubmitButton"')
      end
    end

    context 'with a program that has a grade_finalized_date that has not passed' do
      it 'launches the project in normal edit mode with a submit button' do
        edit_request
        expect(response.body).to include('data-read-only="false"')
        expect(response.body).to include('<div data-react-class="Projects/ProjectSubmitButton"')
      end
    end

    context 'with a program that has a grade_finalized_date that passed' do
      let!(:program) { build :heroku_connect_program,
        canvas_cloud_accelerator_course_id__c: lti_launch.course_id,
        grades_finalized_date__c: Time.now.utc.to_date - 1.day
      }

      context 'with a participant that has a grade_finalized_extension date that has not passed' do
        it 'launches the project in normal edit mode with a submit button' do
          edit_request
          expect(response.body).to include('data-read-only="false"')
          expect(response.body).to include('<div data-react-class="Projects/ProjectSubmitButton"')
        end
      end

      context 'with a participant that has a grade_finalized_extension date that has passed' do
        let!(:participant) { build :heroku_connect_fellow_participant,
          grades_finalized_extension__c: Time.now.utc.to_date - 1.day
        }
        it 'launches the project in read-only mode with no submit button' do
          edit_request
          expect(response.body).to include('data-read-only="true"')
          expect(response.body).not_to include('<div data-react-class="Projects/ProjectSubmitButton"')
        end
      end

      context 'with a participant that does not have a grade_finalized_extension date' do
        let!(:participant) { build :heroku_connect_fellow_participant,
          grades_finalized_extension__c: nil
        }
        it 'launches the project in read-only mode with no submit button' do
          edit_request
          expect(response.body).to include('data-read-only="true"')
          expect(response.body).not_to include('<div data-react-class="Projects/ProjectSubmitButton"')
        end
      end
    end

    context 'with a program that does not have a grade_finalized_date' do
      let!(:program) { build :heroku_connect_program,
        canvas_cloud_accelerator_course_id__c: lti_launch.course_id,
        grades_finalized_date__c: nil
      }
      it 'launches the project in normal edit mode with a submit button' do
        edit_request
        expect(response.body).to include('data-read-only="false"')
        expect(response.body).to include('<div data-react-class="Projects/ProjectSubmitButton"')
      end
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
            lti_launch_id: lti_launch.id,
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
