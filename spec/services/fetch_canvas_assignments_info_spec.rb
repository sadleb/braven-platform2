require 'rails_helper'

RSpec.describe FetchCanvasAssignmentsInfo do

  let(:course_template) { create :course_template_with_canvas_id }
  let(:canvas_client) { double(CanvasAPI) }
  let(:assignments) { [] }

  before(:each) do
    allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    allow(canvas_client).to receive(:get_assignments).and_return(assignments) 
  end

  context 'for waivers' do
    # The URL is hardcoded b/c if we ever change it, it will break previously published waivers.
    let(:waivers_lti_launch_url) { 'https://platformweb/waivers/launch' }
    let(:waiver_assignment) {
      create(:canvas_assignment,
                name: WaiversController::WAIVERS_ASSIGNMENT_NAME,
                course_id: course_template.canvas_course_id,
                lti_launch_url: waivers_lti_launch_url)
    }
    let(:assignments) { [waiver_assignment] } 

    it 'detects a waivers assignment' do
      assignments_info = FetchCanvasAssignmentsInfo.new(course_template.canvas_course_id).run
      expect(assignments_info.canvas_waivers_url).to match(/\/courses\/#{course_template.canvas_course_id}\/assignments\/#{waiver_assignment['id']}/)
      expect(assignments_info.canvas_waivers_assignment_id).to eq(waiver_assignment['id'])
    end
  end

  context 'for non-Braven LTI assignments' do
    let(:non_braven_lti_launch_url) { 'https://some/other/lti/extension/path' }
    let(:non_braven_assignment) {
      create(:canvas_assignment,
                name: 'Watch This Video on Vimeo',
                course_id: course_template.canvas_course_id,
                lti_launch_url: non_braven_lti_launch_url)
    }
    let(:assignments) { [non_braven_assignment] } 

    # We still need the ability to get all assignment IDs in order to set the section due dates.
    it 'detects adds the assignment ID to the array' do
      assignments_info = FetchCanvasAssignmentsInfo.new(course_template.canvas_course_id).run
      expect(assignments_info.canvas_assignment_ids.count).to eq(1)
      expect(assignments_info.canvas_assignment_ids.first).to eq(non_braven_assignment['id'])
    end
  end

end
