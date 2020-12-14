require 'rails_helper'
require 'rise360_util'

RSpec.describe Rise360ModulesController, type: :controller do
  render_views

  let(:state) { LtiLaunchController.generate_state }
  let!(:lti_launch) { create(:lti_launch_assignment_selection, target_link_uri: 'https://target/link', state: state) }
  let(:user) { create :admin_user }
  let(:file_upload) { fixture_file_upload(Rails.root.join('spec/fixtures', 'example_rise360_package.zip'), 'application/zip') }

  before do
    sign_in user
  end

  describe "GET #index" do
    it 'returns a success response' do
      get :index
      expect(response).to be_successful
    end
  end

  describe "GET #new" do
    it "returns a success response" do
      get :new
      expect(response).to be_successful
    end

    it "includes a file input" do
      get :new
      html = '<input class="form-control" required="required" accept="application/zip" type="file" name="rise360_module[rise360_zipfile]" id="rise360_module_rise360_zipfile"'
      expect(response.body).to match Regexp.new(Regexp.quote(html))
    end
  end

  describe "POST #create" do
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
          post :create, params: { 
            rise360_module: {
              name: 'test module',
              rise360_zipfile: file_upload
            },
          }
        }.to change(ActiveStorage::Attachment, :count).by(1)
        expect(Rise360Module.last.rise360_zipfile).to be_attached
      end
    end
  end

  describe "GET #edit" do
    let(:rise360_module) { create :rise360_module }

    it 'returns a success response' do
      get :edit, params: { id: rise360_module.id }
      expect(response).to be_successful
    end
  end

  describe 'PUT #update' do
    let(:rise360_module) { create :rise360_module }

    context 'valid params' do
      before(:each) do
        launch_path = '/lessons/somekey/index.html'
        allow(Rise360Util).to receive(:launch_path).and_return(launch_path)
        allow(Rise360Util).to receive(:publish).and_return(launch_path)
      end

      subject { put(
        :update,
        params: {
          id: rise360_module.id,
          rise360_module: {
            name: 'test module',
            rise360_zipfile: file_upload,
          },
        },
      ) }

      it 'redirects to #index' do
        subject
        expect(response).to redirect_to rise360_modules_path
      end

      it 'updates the name' do
        subject
        expect(rise360_module.reload.name).to eq('test module')
      end

      it 'adds an attachment' do
        expect(rise360_module.rise360_zipfile).not_to be_attached
        subject
        expect(rise360_module.reload.rise360_zipfile).to be_attached
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:rise360_module) { create :rise360_module_with_zipfile }
    subject { delete :destroy, params: { id: rise360_module.id } }

    before(:each) do
      launch_path = '/lessons/somekey/index.html'
      allow(Rise360Util).to receive(:launch_path).and_return(launch_path)
      allow(Rise360Util).to receive(:publish).and_return(launch_path)
      # Trigger creation of module
      rise360_module
    end

    it 'deletes the record' do
      expect { subject }.to change(Rise360Module, :count).by(-1)
    end

    it 'redirects to #index' do
      subject
      expect(response).to redirect_to rise360_modules_path
    end
  end
end
