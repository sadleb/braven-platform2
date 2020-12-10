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
