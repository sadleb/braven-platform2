require 'rails_helper'

RSpec.describe CapstoneEvaluationsController, type: :controller do
  render_views

  let(:canvas_client) { double(CanvasAPI) }
  let(:course) { create :course }
  let(:user) { create :admin_user }

  before(:each) do
    sign_in user
    allow(CanvasAPI).to receive(:client).and_return(canvas_client)
  end

  shared_examples 'updates Capstone Evaluation assignment for the template' do
    scenario 'renders a success notification' do
      expect(flash[:notice]).to match /successfully/
    end

    scenario 'redirects to the edit page' do
      expect(response).to redirect_to(edit_course_path(course))
    end
  end

  describe 'POST #publish' do
    let(:canvas_assignment_id) { 1234 }
    let(:canvas_api_call) { :create_lti_assignment }
    before(:each) do
      allow(canvas_client)
        .to receive(:create_lti_assignment)
        .and_return({ 'id' => canvas_assignment_id })
      allow(canvas_client).to receive(:update_assignment_lti_launch_url)
      post :publish, params: { course_id: course.id }
    end

    # Publishing Capstone Evaluation assignment also published the Capstone Evaluation Results assignment
    it 'creates two new canvas assignments (Capstone Evaluation assignment and Capstone Evaluation Results assignment)' do
      expect(canvas_client)
        .to have_received(canvas_api_call)
        .twice
    end

    it_behaves_like 'updates Capstone Evaluation assignment for the template'
  end

  describe 'DELETE #unpublish' do
    let(:canvas_api_call) { :delete_assignment }
    before(:each) do
      allow(canvas_client).to receive(:delete_assignment)
      delete :unpublish, params: { course_id: course.id, canvas_assignment_id: 123 }
    end

    # Capstone Evaluation assignment and Capstone Evaluation Results assignment are deleted separately
    it 'updates Capstone Evaluation assignment or the Capstone Evaluation Results assignment for the template' do
      expect(canvas_client)
        .to have_received(canvas_api_call)
        .once
    end

    it_behaves_like 'updates Capstone Evaluation assignment for the template'
  end
end
