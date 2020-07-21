require 'rails_helper'

RSpec.describe LessonContentsController, type: :controller do

  # TODO: once we fix this up to not require a logged in platform user, remove this.
  # https://app.asana.com/0/1174274412967132/1184057808812010
  render_views
  let(:user) { create :admin_user }

  before(:each) do
    sign_in user
  end

  # TODO: https://app.asana.com/0/1174274412967132/1184057808812010
  let(:valid_session) { {} } 

  let(:state) { SecureRandom.uuid }
  let(:target_link_uri) { 'https://target/link' }
  let(:lti_launch) { create(:lti_launch_deep_link, target_link_uri: target_link_uri, state: state) }
  let!(:lesson_content) { create(:lesson_content) }

  # describe "GET #new" do
  #   it "returns a success response" do
  #     get :new, params: {state: state}, session: valid_session
  #     expect(response).to be_successful
  #   end

  #   it "includes the existing assignment as an option" do
  #     get :new, params: {state: state}, session: valid_session
  #     expect(response.body).to match /<option value="#{lesson_content.id}"/
  #   end
  # end

  # describe "POST #create" do
  #   context "with valid params" do
  #     it "shows the confirmation form and preview iframe" do
  #       expected_url = LtiDeepLinkingRequestMessage.new(lti_launch.id_token_payload).deep_link_return_url

  #       post :create, params: {state: state, assignment_id: assignment.id}, session: valid_session
  #       expect(response.body).to match /<form action="#{expected_url}"/
  #       expect(response.body).to match /<iframe src=".*\/#{assignment.id}"/
  #     end
  #   end

  #   context "with invalid params" do
  #     it "raises an error when state param is missing" do
  #       expect {
  #         post :create, params: {assignment_id: assignment.id}, session: valid_session
  #       }.to raise_error ActionController::ParameterMissing
  #     end

  #     it "raises an error when assignment_id param is missing" do
  #       expect {
  #         post :create, params: {state: state}, session: valid_session
  #       }.to raise_error ActionController::ParameterMissing
  #     end
  #   end
  # end

end
