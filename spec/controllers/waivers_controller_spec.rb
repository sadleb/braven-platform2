require 'rails_helper'

RSpec.describe WaiversController, type: :controller do
  render_views


  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # WaiversController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  context 'when logged in as admin user' do
    let!(:admin_user) { create :admin_user }
    let(:course) { create :course }
    let(:assignment_name) { WaiversController::WAIVERS_ASSIGNMENT_NAME }
    let(:created_canvas_assignment) { build(:canvas_assignment, course_id: course.canvas_course_id, name: assignment_name) }
    let(:canvas_client) { double(CanvasAPI) }

    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      sign_in admin_user
    end

    describe 'POST #publish' do

      context 'with valid params' do
        let(:valid_publish_params) { {course_id: course.id} }

        before(:each) do
          allow(canvas_client).to receive(:create_lti_assignment).and_return(created_canvas_assignment)
          allow(canvas_client).to receive(:update_assignment_lti_launch_url)
          post :publish, params: valid_publish_params, session: valid_session
        end

        it 'flashes success message' do
          expect(flash[:notice]).to match /successfully published/
        end

        it 'redirects to edit page' do
          expect(response).to redirect_to(edit_course_path(course))
        end

        it 'calls the API correctly' do
          # Hardcoding the path so that if someone changes it they're forced to see this comment
          # and consider that it will break all previously published Waivers assignments.
          expect(canvas_client).to have_received(:create_lti_assignment)
            .with(course.canvas_course_id, assignment_name, nil, WaiversController::WAIVERS_POINTS_POSSIBLE).once
          expect(canvas_client).to have_received(:update_assignment_lti_launch_url)
            .with(
              course.canvas_course_id,
              created_canvas_assignment['id'],
              /waiver_submissions\/launch/,
            ).once
        end

      end

    end # POST#publish

    describe 'POST #unpublish' do

      context 'with valid params' do
        let(:valid_unpublish_params) { {course_id: course.id, canvas_assignment_id: created_canvas_assignment['id']} }

        before(:each) do
          allow(canvas_client).to receive(:delete_assignment).and_return(created_canvas_assignment)
          delete :unpublish, params: valid_unpublish_params, session: valid_session
        end

        it 'flashes success message' do
          expect(flash[:notice]).to match /successfully deleted/
        end

        it 'redirects to edit page' do
          expect(response).to redirect_to(edit_course_path(course))
        end

        it 'calls the API correctly' do
          expect(canvas_client).to have_received(:delete_assignment)
            .with(course.canvas_course_id, created_canvas_assignment['id'].to_s).once
        end

      end

    end # POST #unpublish

  end # logged in as admin user

end
