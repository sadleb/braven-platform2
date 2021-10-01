# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GradeRise360ModuleForUserJob, type: :job do
  describe '#perform' do
    let(:user) { create(:fellow_user) }
    let(:course_rise360_module_version) { create :course_rise360_module_version }
    let(:canvas_assignment_id) { course_rise360_module_version.canvas_assignment_id }
    let(:canvas_course_id) { course_rise360_module_version.course.canvas_course_id }
    let(:lti_launch) {
      create(:lti_launch_assignment,
        canvas_user_id: user.canvas_user_id, canvas_assignment_id: canvas_assignment_id, canvas_course_id: canvas_course_id)
    }
    let(:grading_service) { double(GradeRise360ModuleForUser) }

    subject(:run_job) do
      GradeRise360ModuleForUserJob.perform_now(user, lti_launch)
    end

    it 'calls GradeRise360ModuleForUser with the correct params' do
      expect(GradeRise360ModuleForUser).to receive(:new).with(user, course_rise360_module_version)
        .and_return(grading_service)
      expect(grading_service).to receive(:run).once
      run_job
    end
  end
end
