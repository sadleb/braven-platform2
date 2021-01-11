require 'rails_helper'

RSpec.describe FetchCanvasAssignmentsInfo do

  include Rails.application.routes.url_helpers

  let(:course) { create :course }
  let(:canvas_client) { double(CanvasAPI) }

  before(:each) do
    allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    allow(canvas_client).to receive(:get_assignments).and_return(assignments)
  end

  context 'for fellow evaluation' do
    let(:lti_launch_url) { new_course_fellow_evaluation_submission_path(course) }
    let(:assignment) { create(
      :canvas_assignment,
      course_id: course.canvas_course_id,
      name: 'Fellow Assessment',
      lti_launch_url: lti_launch_url,
    ) }
    let(:assignments) { [ assignment ] }
    
    it 'detects a fellow evaluation assignment' do
      assignments_info = FetchCanvasAssignmentsInfo.new(course.canvas_course_id).run
      expect(assignments_info.canvas_fellow_evaluation_url).to match(/\/courses\/#{course.canvas_course_id}\/assignments\/#{assignment['id']}/)
      expect(assignments_info.canvas_fellow_evaluation_assignment_id).to eq(assignment['id'])
    end
  end

  context 'for peer reviews' do
    let(:peer_reviews_lti_launch_url) { new_course_peer_review_submission_path(course) }
    let(:peer_reviews_assignment) { create(
      :canvas_assignment,
      name: PeerReviewsController::PEER_REVIEWS_ASSIGNMENT_NAME,
      course_id: course.canvas_course_id,
      lti_launch_url: peer_reviews_lti_launch_url,
    ) }
    let(:assignments) { [ peer_reviews_assignment ] }
    
    it 'detects a peer review assignment' do
      assignments_info = FetchCanvasAssignmentsInfo.new(course.canvas_course_id).run
      expect(assignments_info.canvas_peer_reviews_url).to match(/\/courses\/#{course.canvas_course_id}\/assignments\/#{peer_reviews_assignment['id']}/)
      expect(assignments_info.canvas_peer_reviews_assignment_id).to eq(peer_reviews_assignment['id'])
    end
  end

  context 'for waivers' do
    # The URL is hardcoded b/c if we ever change it, it will break previously published waivers.
    let(:waivers_lti_launch_url) { 'https://platformweb/waiver_submissions/launch' }
    let(:waiver_assignment) {
      create(:canvas_assignment,
                name: WaiversController::WAIVERS_ASSIGNMENT_NAME,
                course_id: course.canvas_course_id,
                lti_launch_url: waivers_lti_launch_url)
    }
    let(:assignments) { [waiver_assignment] }

    it 'detects a waivers assignment' do
      assignments_info = FetchCanvasAssignmentsInfo.new(course.canvas_course_id).run
      expect(assignments_info.canvas_waivers_url).to match(/\/courses\/#{course.canvas_course_id}\/assignments\/#{waiver_assignment['id']}/)
      expect(assignments_info.canvas_waivers_assignment_id).to eq(waiver_assignment['id'])
    end
  end

  context 'for non-Braven LTI assignments' do
    let(:non_braven_lti_launch_url) { 'https://some/other/lti/extension/path' }
    let(:non_braven_assignment) {
      create(:canvas_assignment,
                name: 'Watch This Video on Vimeo',
                course_id: course.canvas_course_id,
                lti_launch_url: non_braven_lti_launch_url)
    }
    let(:assignments) { [non_braven_assignment] }

    # We still need the ability to get all assignment IDs in order to set the section due dates.
    it 'detects adds the assignment ID to the array' do
      assignments_info = FetchCanvasAssignmentsInfo.new(course.canvas_course_id).run
      expect(assignments_info.canvas_assignment_ids.count).to eq(1)
      expect(assignments_info.canvas_assignment_ids.first).to eq(non_braven_assignment['id'])
    end
  end

  context 'for projects' do
    let(:course_project_version) { create(:course_project_version, course: course) }

    # The URL is hardcoded b/c if we ever change it, it will break previously published projects.
    let(:project_lti_launch_url) { "https://platformweb/course_project_versions/#{course_project_version.id}/project_submissions/new" }
    let(:project_assignment) {
      create(:canvas_assignment,
                id: course_project_version.canvas_assignment_id,
                course_id: course.canvas_course_id,
                lti_launch_url: project_lti_launch_url)
    }
    let(:assignments) { [project_assignment] }

    it 'detects a project assignment' do
      assignments_info = FetchCanvasAssignmentsInfo.new(course.canvas_course_id).run
      expect(assignments_info.canvas_assignment_ids.count).to eq(1)
      expect(assignments_info.course_project_versions.count).to eq(1)
      expect(assignments_info.course_project_versions.first).to eq(course_project_version)
      expect(assignments_info.course_custom_content_versions_mapping[project_assignment['id']]).to eq(course_project_version)
    end
  end

  context 'for surveys' do
    let(:course_survey_version) { create(:course_survey_version, course: course) }

    # The URL is hardcoded b/c if we ever change it, it will break previously published surveys.
    let(:survey_lti_launch_url) { "https://platformweb/course_survey_versions/#{course_survey_version.id}/survey_submissions/new" }
    let(:survey_assignment) {
      create(:canvas_assignment,
                id: course_survey_version.canvas_assignment_id,
                course_id: course.canvas_course_id,
                lti_launch_url: survey_lti_launch_url)
    }
    let(:assignments) { [survey_assignment] }

    it 'detects a survey assignment' do
      assignments_info = FetchCanvasAssignmentsInfo.new(course.canvas_course_id).run
      expect(assignments_info.canvas_assignment_ids.count).to eq(1)
      expect(assignments_info.course_survey_versions.count).to eq(1)
      expect(assignments_info.course_survey_versions.first).to eq(course_survey_version)
      expect(assignments_info.course_custom_content_versions_mapping[survey_assignment['id']]).to eq(course_survey_version)
    end
  end

end
