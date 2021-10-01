require 'rails_helper'

RSpec.describe AcceleratorSurveysController, type: :controller do
  render_views

  let!(:user) { create :admin_user }
  let(:course) { create :course }
  let(:canvas_client) { double(CanvasAPI) }
  let(:canvas_assignment_id) { '1234' }

  before(:each) do
    sign_in user
    allow(CanvasAPI).to receive(:client).and_return(canvas_client)
  end

  shared_examples 'updates the UI' do
    scenario 'renders a success notification' do
      expect(flash[:notice]).to match /successfully/
    end

    scenario 'redirects to the edit page' do
      expect(response).to redirect_to(edit_course_path(course))
    end
  end

  describe 'POST #publish' do
    shared_examples 'adds the survey as a Canvas assignment' do
      scenario 'creates the Canvas assignment' do
        expect(canvas_client)
          .to have_received(:create_lti_assignment)
          .with(
            course.canvas_course_id,
            title,
            nil,
            AcceleratorSurveysController::ACCELERATOR_SURVEY_POINTS_POSSIBLE
          )
          .once
      end

      scenario 'updates the Canvas assignment LTI launch URL' do
        expect(canvas_client)
          .to have_received(:update_assignment_lti_launch_url)
          .with(
            course.canvas_course_id,
            canvas_assignment_id,
            lti_launch_url,
          )
      end
    end

    context 'valid #publish parameters' do
      before(:each) do
        allow(canvas_client)
          .to receive(:create_lti_assignment)
          .and_return({ 'id' => canvas_assignment_id })
        allow(canvas_client).to receive(:update_assignment_lti_launch_url)
        post :publish, params: { course_id: course.id, type: type }
      end

      ['Pre', 'Post'].each do | type|
        context "#{type}-Accelerator Survey" do
          let(:type) { type }
          let(:title) { "TODO: Complete #{type}-Accelerator Survey"  }
          let(:lti_launch_url) {
            send(
              "launch_#{type.downcase}accelerator_survey_submissions_url",
              protocol: 'https',
            )
          }

          it_behaves_like 'adds the survey as a Canvas assignment'
          it_behaves_like 'updates the UI'
        end
      end
    end

    context 'invalid #publish parameters' do
      it 'should raise error' do
        [
          { course_id: course.id }, # Missing type
          { course_id: course.id , type: 'Foo' }, # Invalid type
          { type: 'Post' }, # Missing course_id
        ].each do | invalid_params |
          expect {
            post :publish, params: invalid_params
          }.to raise_error ActionController::UrlGenerationError
        end
      end
    end
  end

  describe 'DELETE #unpublish' do
    context 'valid #unpublish params' do
      shared_examples 'deletes the survey assignment from the Canvas course' do
        scenario 'creates the Canvas assignment' do
          expect(canvas_client)
            .to have_received(:delete_assignment)
            .with(course.canvas_course_id, canvas_assignment_id)
            .once
        end
      end

      before(:each) do
        allow(canvas_client).to receive(:delete_assignment)
        delete :unpublish, params: {
          course_id: course.id,
          type: type,
          canvas_assignment_id: canvas_assignment_id,
        }
      end

      ['Pre', 'Post'].each do | type |
        context "#{type}-Accelerator Survey" do
          let(:type) { type }

          it_behaves_like 'deletes the survey assignment from the Canvas course'
          it_behaves_like 'updates the UI'
        end
      end
    end

    context 'invalid #unpublish params' do
      it 'raises URL generation error' do
        [
          { canvas_assignment_id: canvas_assignment_id, course_id: course.id }, # Missing type
          { canvas_assignment_id: canvas_assignment_id, course_id: course.id, type: 'Foo' }, # Invalid type
          { canvas_assignment_id: canvas_assignment_id, type: 'Pre' }, # Missing course_id
        ].each do | invalid_params |
          expect {
            delete :unpublish, params: invalid_params
          }.to raise_error ActionController::UrlGenerationError
        end
      end

      context 'missing canvas_assignment_id parameter' do
        it 'raises missing parameter error' do
          expect {
            delete :unpublish, params: { course_id: course.id, type: 'Pre' }
          }.to raise_error ActionController::ParameterMissing
        end
      end
    end
  end
end
