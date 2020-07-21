require 'rails_helper'

RSpec.describe LessonContentsController, type: :controller do
  # TODO: https://app.asana.com/0/1174274412967132/1184057808812010
  render_views

  # FIXME: Getting an error that the user already exists, seems like somehow the DB isn't being cleared
  # out: https://github.com/thoughtbot/factory_bot/issues/1158,
  # but I can't find anywhere where we define user/admin_user outside of factories
  # I have to dbrefresh between runs :(
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

  describe "GET #new" do
    it "returns a success response" do
      get :new, params: {state: state}, session: valid_session
      expect(response).to be_successful
    end

    it "includes a file input" do
      get :new, params: {state: state}, session: valid_session
      expect(response.body).to match /<input type="file" name="lesson_content_zipfile" id="lesson_content_zipfile"/
    end
  end
end
