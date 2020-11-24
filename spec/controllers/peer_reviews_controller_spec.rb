require 'rails_helper'

RSpec.describe PeerReviewsController, type: :controller do
  render_views

  let(:canvas_client) { double(CanvasAPI) }
  let(:course_template) { create :course_template }
  let(:user) { create :admin_user }

  before(:each) do
    sign_in user
    allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    allow(canvas_client).to receive(canvas_api_call)
  end

  shared_examples 'updates Peer Review assignment for the template' do
    scenario 'calls the Canvas API' do
      expect(canvas_client)
        .to have_received(canvas_api_call)
        .once
    end

    scenario 'renders a success notification' do
      expect(flash[:notice]).to match /successfully/
    end

    scenario 'redirects to the edit page' do
      expect(response).to redirect_to(edit_course_template_path(course_template))
    end
  end

  describe 'POST #publish' do
    let(:canvas_api_call) { :create_lti_assignment }

    before(:each) do
      post :publish, params: { base_course_id: course_template.id }
    end

    it_behaves_like 'updates Peer Review assignment for the template'
  end

  describe 'DELETE #unpublish' do
    let(:canvas_api_call) { :delete_assignment }

    before(:each) do
      delete :unpublish, params: { base_course_id: course_template.id, canvas_assignment_id: 123 }
    end

    it_behaves_like 'updates Peer Review assignment for the template'
  end
end
