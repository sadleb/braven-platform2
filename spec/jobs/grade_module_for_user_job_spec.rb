# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GradeModuleForUserJob, type: :job do
  describe '#perform' do
    let(:user) { create(:fellow_user) }
    let(:canvas_assignment_id) { course_rise360_module_version.canvas_assignment_id }
    let(:canvas_course_id) { course_rise360_module_version.course.canvas_course_id }
    let(:activity_id) { 'https://some/activity/id' }
    let(:raw_grade) { 75 }
    let(:manually_graded) { false }
    let(:canvas_client) { double(CanvasAPI) }
    let(:assignment_overrides) { [] }
    let(:course_rise360_module_version) { create :course_rise360_module_version }
    let!(:rise360_module_grade) { create :rise360_module_grade, user: user, course_rise360_module_version: course_rise360_module_version }

    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(canvas_client).to receive(:update_grade)
      allow(canvas_client).to receive(:get_assignment_overrides).and_return(assignment_overrides)
      allow(canvas_client).to receive(:latest_submission_manually_graded?).and_return(manually_graded)
      allow(ModuleGradeCalculator).to receive(:compute_grade).and_return(raw_grade)
    end

    subject(:run_job) do
      GradeModuleForUserJob.perform_now(user, canvas_course_id, canvas_assignment_id)
    end

    it 'calls ModuleGradeCalculator with the correct params' do
      run_job
      expect(ModuleGradeCalculator).to have_received(:compute_grade)
        .with(user.id, canvas_assignment_id, assignment_overrides).once
    end

    shared_examples 'processess module interactions' do
      it 'sets the module interactions to have status graded (aka not new)' do
        rmi = create(:ungraded_progressed_module_interaction, user: user,
          progress: 100, activity_id: activity_id, canvas_course_id: canvas_course_id, canvas_assignment_id: canvas_assignment_id
        )
        another_user = create(:fellow_user, canvas_user_id: 9876543)
        rmi_another_user = create(:ungraded_progressed_module_interaction, user: another_user,
          progress: 100, activity_id: activity_id, canvas_course_id: canvas_course_id, canvas_assignment_id: canvas_assignment_id
        )

        run_job

        expect(Rise360ModuleInteraction.where(new: true, user: user,
          canvas_course_id: canvas_course_id, canvas_assignment_id: canvas_assignment_id)
        ).to be_empty
        expect(Rise360ModuleInteraction.where(new: false, user: user,
          canvas_course_id: canvas_course_id, canvas_assignment_id: canvas_assignment_id).count
        ).to be(1)
        expect(Rise360ModuleInteraction.where(new: true, user: another_user,
          canvas_course_id: canvas_course_id, canvas_assignment_id: canvas_assignment_id).count
        ).to be(1)
      end
    end


    context 'when not manually graded' do
      let(:manually_graded) { false }

      it 'calls into CanvasAPI to update the grade' do
        run_job
        expect(canvas_client).to have_received(:update_grade)
          .with(canvas_course_id, canvas_assignment_id, user.canvas_user_id, "#{raw_grade}%").once
      end

      it_behaves_like 'processess module interactions'
    end

    context 'when manually graded' do
      let(:manually_graded) { true }

      it 'calls into CanvasAPI to check if it was manually graded and auto-grading should be off' do
        run_job
        expect(canvas_client).to have_received(:latest_submission_manually_graded?)
          .with(canvas_course_id, canvas_assignment_id, user.canvas_user_id).once
      end

      it 'does not call into CanvasAPI to get the overrides' do
        run_job
        expect(canvas_client).not_to have_received(:get_assignment_overrides)
      end

      it 'does not call compute_grade' do
        run_job
        expect(ModuleGradeCalculator).not_to have_received(:compute_grade)
      end

      it 'does not call into CanvasAPI to update_grade' do
        run_job
        expect(canvas_client).not_to have_received(:update_grade)
      end

      it_behaves_like 'processess module interactions'
    end
  end
end
