require 'rails_helper'
require 'canvas_api'

RSpec.describe CourseSurveyVersionsController, type: :controller do
  render_views

  let(:canvas_client) { double(CanvasAPI) }
  let!(:admin_user) { create :admin_user }
  let(:course) { create :course }

  before do
    sign_in admin_user
  end

  describe 'GET #new' do
    let(:survey_version) { create :survey_version }
    let!(:course_survey_version) { create(
      :course_survey_version,
      course: course,
      survey_version: survey_version,
    ) }

    it 'returns a success response' do
      get :new, params: { course_id: course.id }
      expect(response).to be_successful
    end

    it 'excludes modules that have already been added to the course' do
      unpublished_survey = Survey.create!(title: 'New Survey')
      get :new, params: { course_id: course.id }
      expect(response.body).to match /<option value="#{unpublished_survey.id}">#{unpublished_survey.title}<\/option>/
      expect(response.body).not_to match /<option.*>#{course_survey_version.survey_version.title}<\/option>/
    end
  end

  describe 'POST #publish' do
    let(:canvas_assignment_id) { 1234 }
    let(:survey) { create :survey }

    subject {
      post :publish, params: {
        course_id: course.id,
        custom_content_id: survey.id,
      }
    }

    context 'Canvas assignment creation succeeds' do
      before(:each) do
        allow(CanvasAPI).to receive(:client).and_return(canvas_client)
        allow(canvas_client)
          .to receive(:create_lti_assignment)
          .and_return({ 'id' => canvas_assignment_id })
        allow(canvas_client)
          .to receive(:update_assignment_lti_launch_url)
      end

      it 'adds a new join table entry' do
        expect { subject }.to change(CourseSurveyVersion, :count).by(1)
        course_survey_version = CourseSurveyVersion.last
        expect(course_survey_version.canvas_assignment_id).to eq(canvas_assignment_id)
        expect(course_survey_version.course).to eq(course)
        expect(course_survey_version.survey_version).to eq(SurveyVersion.last)
      end

      it 'creates a new version' do
        expect { subject }.to change(SurveyVersion, :count).by(1)
      end

      it 'adds the survey to the course' do
        subject
        expect(course.surveys).to include(CourseSurveyVersion.last.survey_version.survey)
      end

      it 'creates a new Canvas assignment' do
        subject
        expect(canvas_client)
          .to have_received(:create_lti_assignment)
          .with(course.canvas_course_id, survey.title)
          .once
        expect(canvas_client)
          .to have_received(:update_assignment_lti_launch_url)
          .with(
            course.canvas_course_id,
            canvas_assignment_id,
            CourseSurveyVersion.last.new_submission_url,
          )
          .once
      end

      it 'redirects to course edit page' do
        subject
        expect(response).to redirect_to edit_course_path(course)
      end
    end

    context 'Canvas assignment creation fails' do
      before(:each) do
        allow(CanvasAPI).to receive(:client).and_return(canvas_client)
        allow(canvas_client)
          .to receive(:create_lti_assignment)
          .and_raise(RestClient::BadRequest)
      end

      it 'does not create the join table entry' do
        expect {
          subject rescue nil
        }.not_to change(CourseSurveyVersion, :count)
      end
    end
  end

  describe 'DELETE #unpublish' do
    let(:survey_version) { create :survey_version }
    let!(:course_survey_version) { create(
      :course_survey_version,
      course: course,
      survey_version: survey_version,
    )}

    subject {
      delete :unpublish, params: {
        course_id: course.id,
        id: course_survey_version.id,
      }
    }

    context 'Canvas assignment not found' do
      before(:each) do
        allow(CanvasAPI).to receive(:client).and_return(canvas_client)
        allow(canvas_client)
          .to receive(:delete_assignment)
          .and_raise(RestClient::NotFound)
      end

      it 'deletes the join table entry' do
        expect { subject rescue nil }.to change(CourseSurveyVersion, :count).by(-1)
      end
    end

    context 'Unhandled Canvas error' do
      before(:each) do
        allow(CanvasAPI).to receive(:client).and_return(canvas_client)
        allow(canvas_client)
          .to receive(:delete_assignment)
          .and_raise(RestClient::BadRequest)
      end

      it 'does not delete the join table entry' do
        expect { subject rescue nil }.not_to change(CourseSurveyVersion, :count)
      end
    end

    context 'Canvas assignment found' do
      before(:each) do
        allow(CanvasAPI).to receive(:client).and_return(canvas_client)
        allow(canvas_client)
          .to receive(:delete_assignment)
      end

      it 'deletes the join table entry' do
        expect { subject }.to change(CourseSurveyVersion, :count).by(-1)
      end

      it 'deletes the Canvas assignment' do
        subject
        expect(canvas_client)
          .to have_received(:delete_assignment)
          .with(course.canvas_course_id, course_survey_version.canvas_assignment_id)
          .once
      end

      it 'does not delete the version' do
        expect { subject }.not_to change { SurveyVersion.count }
      end

      it 'does not delete the course' do
        expect { subject }.not_to change { Course.count }
      end

      it 'redirects to course edit page' do
        subject
        expect(response).to redirect_to edit_course_path(course)
      end
    end
  end

  describe 'PUT #publish_latest' do
    let(:survey_version) { create :survey_version }
    let!(:course_survey_version) { create(
      :course_survey_version,
      course: course,
      survey_version: survey_version,
    )}

    subject {
      put :publish_latest, params: {
        course_id: course.id,
        id: course_survey_version.id,
      }
    }

    context 'Canvas API exception' do
      before(:each) do
        allow(CanvasAPI).to receive(:client).and_return(canvas_client)
        allow(canvas_client)
          .to receive(:update_assignment_name)
          .and_raise(RestClient::BadRequest)
        allow(canvas_client)
          .to receive(:update_assignment_lti_launch_url)
          .and_raise(RestClient::BadRequest)
      end

      it 'does not change the join table entry' do
        existing_course_survey_version = course_survey_version
        expect { subject rescue nil }.not_to change(CourseSurveyVersion, :count)
        expect(CourseSurveyVersion.last).to eq(existing_course_survey_version)
      end
    end

    context 'Canvas assignment found' do
      before(:each) do
        allow(CanvasAPI).to receive(:client).and_return(canvas_client)
        allow(canvas_client).to receive(:update_assignment_name)
        allow(canvas_client).to receive(:update_assignment_lti_launch_url)
      end

      it 'updates the assignment name' do
        subject
        expect(canvas_client)
          .to have_received(:update_assignment_name)
          .with(
            course.canvas_course_id,
            course_survey_version.canvas_assignment_id,
            course_survey_version.reload.survey_version.title,
          )
          .once
      end

      it 'updates the LTI launch URL' do
        subject
        expect(canvas_client)
          .to have_received(:update_assignment_lti_launch_url)
          .with(
            course.canvas_course_id,
            course_survey_version.canvas_assignment_id,
            course_survey_version.reload.new_submission_url,
          )
          .once
      end

      it 'redirects to course edit page' do
        subject
        expect(response).to redirect_to edit_course_path(course)
      end

      it 'creates a new version' do
        prev_version = course_survey_version.survey_version
        expect { subject }.to change(SurveyVersion, :count).by(1)
        expect(course_survey_version.reload.survey_version).not_to eq(prev_version)
        expect(course_survey_version.reload.survey_version).to eq(SurveyVersion.last)
      end

      it 'updates the existing join table entry' do
        expect { subject }.not_to change { CourseSurveyVersion.count }
      end
    end
  end
end
