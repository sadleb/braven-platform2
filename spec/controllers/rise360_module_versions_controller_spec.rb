require 'rails_helper'
require 'rise360_util'

RSpec.describe Rise360ModuleVersionsController, type: :controller do
  render_views

  let(:state) { LtiLaunchController.generate_state }
  let(:lti_launch) { create(:lti_launch_assignment_selection, target_link_uri: 'https://target/link', state: state) }
  let(:user) { create :registered_user, canvas_user_id: lti_launch.request_message.canvas_user_id }
  let(:rise360_module_version) { create :rise360_module_version_with_zipfile }

  before do
    sign_in user
  end

  describe "GET #show" do
    it 'redirects to public url with LRS query parameters' do 
      launch_path = '/lessons/somekey/index.html' 
      allow(Rise360Util).to receive(:launch_path).and_return(launch_path) 
      allow(Rise360Util).to receive(:publish).and_return(launch_path) 

      get :show, params: {:id => rise360_module_version.id, :state => state}

      redirect_url = Addressable::URI.parse(response.location)  
      expected_url =  Addressable::URI.parse(rise360_module_version.launch_url)  
      expect(redirect_url.path).to eq(expected_url.path)  

      # Specific LRS query parameters are tested in LtiHelper 
      expect(redirect_url.query_values).not_to be_empty 
    end 
  end
end
