require 'rails_helper'

RSpec.describe SurveySubmissionsController, type: :controller do
  render_views

  let(:course_survey_version) { create(:course_survey_version) }
  let(:section) { create :section, course: course_survey_version.course }
  let(:user) { create :fellow_user, section: section }

  let(:lti_launch) {
    create(
      :lti_launch_assignment,
      canvas_user_id: user.canvas_user_id,
    )
  }

  before :each do
    sign_in user
  end
 
  describe 'GET #show' do
    # This creates the submission for the Fellow for that survey
    # The survey_submission has to be created here so it doesn't interfere with
    # the POST #create SurveySubmission counts
    let(:survey_submission) { create(
      :survey_submission,
      user: user,
      course_survey_version: course_survey_version,
    )}

    it 'returns a success response' do
      get(
        :show,
        params: {
          id: survey_submission.id,
          type: 'CourseSurveyVersion',
          lti_launch_id: lti_launch.id,
        },
      )
      expect(response).to be_successful
    end
  end

  describe 'GET #new' do
    it 'returns a success response' do
      get(
        :new,
        params: {
          course_survey_version_id: course_survey_version.id,
          type: 'CourseSurveyVersion',
          lti_launch_id: lti_launch.id,
        },
      )
      expect(response).to be_successful
    end

    it 'redirects to #show if there is a previous submission' do
      SurveySubmission.create!(
        user: user,
        course_survey_version: course_survey_version,
      )
      get(
        :new,
        params: {
          course_survey_version_id: course_survey_version.id,
          type: 'CourseSurveyVersion',
          lti_launch_id: lti_launch.id,
        },
      )
      expect(response).to redirect_to survey_submission_path(SurveySubmission.last, lti_launch_id: lti_launch.id)
    end
  end

  describe 'POST #create' do
    let(:lti_advantage_api) { double(LtiAdvantageAPI) }

    before(:each) do
      allow(LtiAdvantageAPI).to receive(:new).and_return(lti_advantage_api)
      allow(lti_advantage_api).to receive(:create_score)
      allow(LtiScore).to receive(:new_full_credit_submission)
    end

    subject {
      post(
        :create,
        params: {
          course_survey_version_id: course_survey_version.id,
          type: 'CourseSurveyVersion',
          unique_input_name: 'my test input',
          lti_launch_id: lti_launch.id,
        }
      )
    }

    it 'redirects to #show' do
      expect(subject).to redirect_to survey_submission_path(SurveySubmission.last, lti_launch_id: lti_launch.id)
    end

    it 'creates a survey submission' do
      expect { subject }.to change(SurveySubmission, :count).by(1)
    end

    it 'saves the submitted answer' do
      expect { subject }.to change(SurveySubmissionAnswer, :count).by(1)
    end

    it 'updates the Canvas assignment' do
      subject
      expect(lti_advantage_api)
        .to have_received(:create_score)
        .once
    end
  end
end
