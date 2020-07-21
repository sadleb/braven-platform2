require 'rails_helper'

RSpec.describe LessonContentsController, type: :controller do
  # TODO: https://app.asana.com/0/1174274412967132/1184057808812010
  render_views

  # This errors out if DB isn't cleaned up if rspec errors out:
  # https://stackoverflow.com/questions/9927671/rspec-database-cleaner-not-cleaning-correctly
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
  let!(:lesson_content_zipfile) { file = fixture_file_upload(Rails.root.join('spec/fixtures', 'example_rise360_package.zip'), 'application/zip') }

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

  describe "GET #show" do
    context 'existing lesson content' do
      it 'redirects to public url' do
        launch_url = LessonContentPublisher.launch_url(lesson_content.lesson_content_zipfile.key)
        # FIXME: You can't us pass "id" as parameter. :( But that's what rails routes expects.
        get :show, params: {:id => lesson_content.id}, session: valid_session
        expect(response).to redirect_to(launch_url)
      end
    end
  end

  # FIXME: these all have LtiLaunch in DB issues now?
  describe "POST #create" do
    context "with invalid params" do
      it "raises an error when state param is missing" do
        expect {
          post :create, params: {lesson_content_zipfile: lesson_content_zipfile}, session: valid_session
        }.to raise_error ActionController::ParameterMissing
      end

      it "raises an error when zipfile param is missing" do
        expect {
          post :create, params: {state: state}, session: valid_session
        }.to raise_error ActionController::ParameterMissing
      end
    end

    context "with valid params" do
      it "shows the confirmation form and preview iframe" do
        expected_url = LtiDeepLinkingRequestMessage.new(lti_launch.id_token_payload).deep_link_return_url

        post :create, params: {state: state, lesson_content_zipfile: lesson_content_zipfile}, session: valid_session
        expect(response.body).to match /<form action="#{expected_url}"/
        # FIXME: Don't hardcode 1 here and there's something wrong with this regex :(
        expect(response.body).to match /<iframe src=".*\/#{1}"/
      end

      # From: https://www.dwightwatson.com/posts/testing-activestorage-uploads-in-rails-52
      it 'attaches uploaded zipfile' do
        expect {
          post :create, params: {state: state, lesson_content_zipfile: file} , session: valid_session
        }.to change(ActiveStorage::Attachment, :count).by(1)
        # expect(@lesson_content.lesson_content_zipfile).to be_attached
      end
    end
  end

end
