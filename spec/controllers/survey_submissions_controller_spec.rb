require 'rails_helper'

RSpec.describe SurveySubmissionsController, type: :controller do
  render_views

  let(:course_survey_version) { create(:course_survey_version) }
  let(:section) { create :section, course: course_survey_version.base_course }
  let(:user) { create :fellow_user, section: section }
 
  before do
    sign_in user
  end

  describe 'GET #show' do
    # This creates the submission for the Fellow for that survey
    # The survey_submission has to be created here so it doesn't interfere with
    # the POST #create SurveySubmission counts
    let(:survey_submission) { create(
      :survey_submission,
      user: user,
      base_course_survey_version: course_survey_version,
    )}

    it 'returns a success response' do
      get(
        :show,
        params: { id: survey_submission.id, type: 'BaseCourseSurveyVersion' },
      )
      expect(response).to be_successful
    end
  end

  describe 'GET #new' do
    it 'returns a success response' do
      get(
        :new,
        params: {
          base_course_survey_version_id: course_survey_version.id,
          type: 'BaseCourseSurveyVersion'
        },
      )
      expect(response).to be_successful
    end
  end

  describe 'POST #create' do
    subject {
      post(
        :create,
        params: {
          base_course_survey_version_id: course_survey_version.id,
          type: 'BaseCourseSurveyVersion',
          # This key has to match the ... in <input name="..."> in the 
          # course_survey_version.survey_version.body being used
          unique_input_name: 'my test input',
        }
      )
    }

    it 'redirects to #show' do
      expect(subject).to redirect_to survey_submission_path(SurveySubmission.last)
    end

    it 'creates a survey submission' do
      expect { subject }.to change(SurveySubmission, :count).by(1)
    end

    it 'creates a response' do
      expect { subject }.to change(SurveySubmissionAnswer, :count).by(1)
    end

    xit 'updates the Canvas assignment' do
        # TODO: https://app.asana.com/0/1174274412967132/1198971448730205
      # Update Canvas assignment with line item/submission
    end
  end
end
