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

  context 'for projects' do
    let(:course_template_project_version) { create(:course_template_project_version, base_course: course_template) }

    # The URL is hardcoded b/c if we ever change it, it will break previously published projects.
    let(:project_lti_launch_url) { "https://platformweb/base_course_project_versions/#{course_template_project_version.id}/project_submissions/new" }
    let(:project_assignment) {
      create(:canvas_assignment,
                id: course_template_project_version.canvas_assignment_id,
                course_id: course_template.canvas_course_id,
                lti_launch_url: project_lti_launch_url)
    }
    let(:assignments) { [project_assignment] }

    it 'detects a project assignment' do
      assignments_info = FetchCanvasAssignmentsInfo.new(course_template.canvas_course_id).run
      expect(assignments_info.canvas_assignment_ids.count).to eq(1)
      expect(assignments_info.base_course_project_versions.count).to eq(1)
      expect(assignments_info.base_course_project_versions.first).to eq(course_template_project_version)
      expect(assignments_info.base_course_custom_content_versions_mapping[project_assignment['id']]).to eq(course_template_project_version)
    end
  end

  context 'for surveys' do
    let(:course_template_survey_version) { create(:course_template_survey_version, base_course: course_template) }

    # The URL is hardcoded b/c if we ever change it, it will break previously published surveys.
    let(:survey_lti_launch_url) { "https://platformweb/base_course_survey_versions/#{course_template_survey_version.id}/survey_submissions/new" }
    let(:survey_assignment) {
      create(:canvas_assignment,
                id: course_template_survey_version.canvas_assignment_id,
                course_id: course_template.canvas_course_id,
                lti_launch_url: survey_lti_launch_url)
    }
    let(:assignments) { [survey_assignment] }

    it 'detects a survey assignment' do
      assignments_info = FetchCanvasAssignmentsInfo.new(course_template.canvas_course_id).run
      expect(assignments_info.canvas_assignment_ids.count).to eq(1)
      expect(assignments_info.base_course_survey_versions.count).to eq(1)
      expect(assignments_info.base_course_survey_versions.first).to eq(course_template_survey_version)
      expect(assignments_info.base_course_custom_content_versions_mapping[survey_assignment['id']]).to eq(course_template_survey_version)
    end
  end

end
