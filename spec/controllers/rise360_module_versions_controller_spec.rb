require 'rails_helper'
require 'rise360_util'

RSpec.describe Rise360ModuleVersionsController, type: :controller do
  render_views

  let(:lti_score_response) { build(:lti_score_response) }
  let(:lti_advantage_client) { double(LtiAdvantageAPI) }
  let(:state) { LtiLaunchController.generate_state }
  let(:course) { create :course }
  let(:launch_path) { '/lessons/somekey/index.html' }
  let(:rise360_module_version) { create :rise360_module_version_with_zipfile }
  let(:course_rise360_module_version) { create(
    :course_rise360_module_version,
    course: course,
    rise360_module_version: rise360_module_version,
  ) }
  let(:lti_launch) {
    create(:lti_launch_assignment,
      state: state,
      course_id: course.canvas_course_id,
      assignment_id: course_rise360_module_version.canvas_assignment_id)
  }
  let(:user) { create :registered_user, canvas_user_id: lti_launch.request_message.canvas_user_id }

  before do
    allow(Rise360Util).to receive(:launch_path).and_return(launch_path)
    allow(Rise360Util).to receive(:publish).and_return(launch_path)
    allow(lti_advantage_client).to receive(:create_score).and_return(lti_score_response)
    allow(LtiAdvantageAPI).to receive(:new).and_return(lti_advantage_client)
    sign_in user
  end

  describe "GET #show" do
    it 'loads the public url with xAPI query parameters in an iframe' do
      get :show, params: {:id => rise360_module_version.id, :state => state}

      expected_url =  Addressable::URI.parse(rise360_module_version.launch_url)
      expect(response.body).to match /<iframe id="rise360-iframe" src="#{expected_url.path}\?.*=.*">/
      # Note that specific xAPI query parameters are tested in LtiHelper. We just want to make
      # sure they are being added.
    end

    context 'when Fellow opens first time' do
      let(:lti_score_request) { build(:lti_score) }
      let(:lti_score_response) { build(:lti_score_response) }
      let(:section) { create :section, course: course }
      let(:user) { create :fellow_user, section: section, canvas_user_id: lti_launch.request_message.canvas_user_id }

      it 'creates Rise360ModuleGrade' do
        expect {
          get :show, params: {:id => rise360_module_version.id, :state => state}
        }.to change(Rise360ModuleGrade, :count).by(1)
      end

      it 'creates a Canvas submission' do
        allow(LtiScore).to receive(:new_module_submission).and_return(lti_score_request)

        get :show, params: {:id => rise360_module_version.id, :state => state}

        grade = Rise360ModuleGrade.find_by(
          user: user,
          course_rise360_module_version: course_rise360_module_version
        )
        expect(LtiScore).to have_received(:new_module_submission)
          .with(user.canvas_user_id, rise360_module_grade_url(grade, protocol: 'https')).once
        expect(lti_advantage_client).to have_received(:create_score).with(lti_score_request).once
        expect(grade.canvas_results_url).to eq(lti_score_response['resultUrl'])
      end
    end

    context 'when Fellow opens subsequent times' do
      before(:each) do
        Rise360ModuleGrade.create!(
          user: user,
          course_rise360_module_version: course_rise360_module_version,
        )
      end

      it 'does not create a new Rise360ModuleGrade' do
        expect {
          get :show, params: {:id => rise360_module_version.id, :state => state}
        }.to change(Rise360ModuleGrade, :count).by(0)
      end

      it 'does not create a Canvas submission' do
        get :show, params: {:id => rise360_module_version.id, :state => state}
        expect(lti_advantage_client).not_to have_received(:create_score)
      end

    end
  end
end
