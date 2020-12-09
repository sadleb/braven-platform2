require 'rails_helper'
require 'rise360_util'

RSpec.describe Rise360ModulesController, type: :controller do
  render_views

  let(:state) { LtiLaunchController.generate_state }
  let!(:lti_launch) { create(:lti_launch_assignment_selection, target_link_uri: 'https://target/link', state: state) }
  let(:user) { create :admin_user }

  before do
    sign_in user
  end

  describe "GET #new" do
    it "returns a success response" do
      get :new
      expect(response).to be_successful
    end

    it "includes a file input" do
      get :new
      expect(response.body).to match /<input type="file" name="rise360_zipfile" id="rise360_zipfile"/
    end
  end

  describe "GET #show" do
    let!(:user) { create :registered_user, canvas_user_id: lti_launch.request_message.canvas_user_id }
    let(:rise360_module_with_zipfile) { create(:rise360_module_with_zipfile) }

    context 'existing lesson content' do
      it 'redirects to public url with LRS query parameters' do
        launch_path = '/lessons/somekey/index.html'
        allow(Rise360Util).to receive(:launch_path).and_return(launch_path)
        allow(Rise360Util).to receive(:publish).and_return(launch_path)

        get :show, params: {:id => rise360_module_with_zipfile.id, :state => state}

        redirect_url = Addressable::URI.parse(response.location)
        expected_url =  Addressable::URI.parse(rise360_module_with_zipfile.launch_url)
        expect(redirect_url.path).to eq(expected_url.path)

        # Specific LRS query parameters are tested in LtiHelper
        expect(redirect_url.query_values).not_to be_empty
      end
    end
  end

  describe "POST #create" do
    let(:file_upload) { fixture_file_upload(Rails.root.join('spec/fixtures', 'example_rise360_package.zip'), 'application/zip') }

    context "with invalid params" do
      it "raises an error when zipfile param is missing" do
        expect {
          post :create
        }.to raise_error ActionController::ParameterMissing
      end
    end

    context "with valid params" do
      it 'attaches uploaded zipfile' do
        launch_path = '/lessons/somekey/index.html'
        allow(Rise360Util).to receive(:launch_path).and_return(launch_path)
        allow(Rise360Util).to receive(:publish).and_return(launch_path)

        expect {
          post :create, params: {name: 'test module', rise360_zipfile: file_upload}
        }.to change(ActiveStorage::Attachment, :count).by(1)
        expect(Rise360Module.last.rise360_zipfile).to be_attached
      end
    end
  end
end
