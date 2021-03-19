require 'rails_helper'

RSpec.describe Rise360ModuleGradesController, type: :controller do
  render_views

  let(:state) { LtiLaunchController.generate_state }
  let(:course) { create :course }
  let(:course_rise360_module_version) {
    create( :course_rise360_module_version, course: course)
  }
  let(:user_with_grade) { create :fellow_user, canvas_user_id: '987432' }
  let(:user_viewing) { user_with_grade }
  let(:rise360_module_grade) {
    create :rise360_module_grade, user: user_with_grade, course_rise360_module_version: course_rise360_module_version
  }
  let(:rise360_module_interaction_ungraded) {
    create(:ungraded_progressed_module_interaction,
      user: user_with_grade,
      canvas_course_id: course.canvas_course_id,
      canvas_assignment_id: course_rise360_module_version.canvas_assignment_id
    )
  }
  let(:rise360_module_interaction_graded) {
    create(:graded_progressed_module_interaction,
      user: user_with_grade,
      canvas_course_id: course.canvas_course_id,
      canvas_assignment_id: course_rise360_module_version.canvas_assignment_id
    )
  }
  let!(:lti_launch) {
    create(:lti_launch_assignment,
      state: state,
      canvas_user_id: user_viewing.canvas_user_id,
      canvas_course_id: course.canvas_course_id,
      canvas_assignment_id: course_rise360_module_version.canvas_assignment_id)
  }

  before do
    sign_in user_viewing
  end

  describe 'GET #show' do
    it 'returns a success response' do
      get :show, params: {:id => rise360_module_grade.id, :state => state}
      expect(response).to be_successful
    end

    it 'links to the Module itself' do
      get :show, params: {:id => rise360_module_grade.id, :state => state}
      expect(response.body).to match /<a href="#{Regexp.escape(course_rise360_module_version.canvas_url)}" target="_parent"/  
    end

    it 'doesnt show a message about the grade being out-of-date' do
      rise360_module_interaction_graded
      get :show, params: {:id => rise360_module_grade.id, :state => state}
      expect(response.body).to match(/Your grade for this Module is at the top of the screen/)
      expect(response.body).not_to match(/most recent work hasn't been graded yet/)
    end

    it 'there is a message about the grade being out-of-date' do
      rise360_module_interaction_ungraded
      get :show, params: {:id => rise360_module_grade.id, :state => state}
      expect(response.body).to match(/most recent work hasn't been graded yet/)
    end
  end

end

