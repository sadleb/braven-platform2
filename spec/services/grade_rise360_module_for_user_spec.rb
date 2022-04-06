# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GradeRise360ModuleForUser do

  let(:course) { create(:course) }
  let(:section) { create(:cohort_section, course: course) }
  let(:user) { create(:fellow_user, section: section) }
  let(:rise360_module_version) { create(:rise360_module_version) }
  let(:course_rise360_module_version) { create(:course_rise360_module_version,
    course: course,
    rise360_module_version: rise360_module_version,
  ) }
  let(:canvas_assignment_id) { course_rise360_module_version.canvas_assignment_id }
  let(:canvas_api_user_id) { 9954321 }
  let(:due_date) { (Time.now + 1.week).utc.iso8601 } # future due date
  let(:graded_at) { (Time.now - 1.day).utc.iso8601 }
  let(:submission_score) { 5.0 }
  let(:grader_id) { canvas_api_user_id }
  let(:canvas_submission) {
    create :canvas_submission,
      cached_due_date: due_date,
      grader_id: grader_id,
      graded_at: graded_at,
      score: submission_score
  }

  let(:force_computation) { false }
  let(:send_grade_to_canvas) { true }
  let(:canvas_submission_param) { nil }
  let(:grade_service) {
    GradeRise360ModuleForUser.new(
      user,
      course_rise360_module_version,
      force_computation,
      send_grade_to_canvas,
      canvas_submission_param
     )
  }
  let(:canvas_client) { double(CanvasAPI) }
  let(:compute_service) { double(ComputeRise360ModuleGrade) }

  let(:engagement_grade) { 0 }
  let(:quiz_grade) { 0 }
  let(:on_time_grade) { 0 }
  let(:completed_at) { nil }
  let(:grade_breakdown) {
     ComputeRise360ModuleGrade::ComputedGradeBreakdown.new(
       engagement_grade,
       quiz_grade,
       on_time_grade,
       completed_at
     )
  }

  let(:on_time_credit_received) { false }
  let(:rise360_module_grade){
    create :rise360_module_grade,
      user: user,
      course_rise360_module_version: course_rise360_module_version,
      on_time_credit_received: on_time_credit_received
  }

  before(:each) do
    allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    allow(canvas_client).to receive(:api_user_id).and_return(canvas_api_user_id)
    allow(canvas_client).to receive(:get_latest_submission)
      .with(course.canvas_course_id, canvas_assignment_id, user.canvas_user_id)
      .and_return(canvas_submission)

    allow(ComputeRise360ModuleGrade).to receive(:new).and_return(compute_service)
    allow(compute_service).to receive(:run).and_return(grade_breakdown)
  end

  # These tests stub out the needs_grading? logic and test the permutations of how
  # the service can be initialized with different behavior. needs_grading? tests
  # later in this file focus on the core logic, like manual overrides or needing a zero.
  describe '#run' do
    subject(:run_service) { grade_service.run() }

    shared_examples 'grade not computed' do
      it 'does not run computation and returns nil' do
        expect(compute_service).not_to receive(:run)
        expect(run_service).to eq(nil)
      end
    end

    shared_examples 'grade computed' do

      before(:each) do
        allow(canvas_client).to receive(:update_grade)
      end

      context 'when computed grade is higher than Canvas grade' do
        let(:submission_score) { 3.0 }
        let(:engagement_grade) { 100 } # worth 4.0 points
        it 'computes and returns the new grade breakdown' do
          expect(compute_service).to receive(:run)
          expect(run_service).to eq(4.0)
        end
      end

      context 'when computed grade is lower than Canvas grade' do
        let(:submission_score) { 5.0 }
        let(:engagement_grade) { 100 } # worth 4.0 points
        it 'computes and returns nil' do
          expect(compute_service).to receive(:run)
          expect(run_service).to eq(nil)
        end
      end

      # NOTE: the tests for how the points are displayed are in rise360_module_grades_controller_spec.rb
      # and compute_rise360_module_grade_spec
    end

    shared_examples 'grade not sent to canvas' do
      it 'does not call CanvasAPI#update_grade' do
        expect(canvas_client).not_to receive(:update_grade)
        run_service
      end

      # We only want to mark them as new == false when they are successfully sent to Canvas.
      it 'leaves interactions as ungraded' do
        # Stick a random ungraded interaction in there so we can see that it's left as ungraded after.
        create(:ungraded_progressed_module_interaction,
          canvas_course_id: course.canvas_course_id,
          user: user,
          canvas_assignment_id: canvas_assignment_id,
          progress: 50,
        )

        # Verify all interactions are marked as old after running the service
        interactions = Rise360ModuleInteraction.where(user: user, canvas_assignment_id: canvas_assignment_id, new: true)
        expect(interactions.count).to eq(1)

        run_service

        interactions.reload.each do |interaction|
          expect(interaction.new).to eq(true)
        end
      end

      # Even if module completion is 100% before the due date, we don't want to cache
      # their on-time grade until it is sent to Canvas.
      context 'when module completion reaches 100% before the due date' do
        let(:on_time_grade) { 100 }
        it 'does not cache their on-time grade' do
          expect{ run_service }.not_to change{ rise360_module_grade.reload.on_time_credit_received }
        end
      end
    end

    shared_examples 'grade sent to canvas' do
      let(:submission_score) { 3.0 }
      let(:engagement_grade) { 100 } # worth 4.0 points

      before(:each) do
        allow(canvas_client).to receive(:update_grade)
      end

      it 'calls CanvasAPI#update_grade' do
        expect(canvas_client).to receive(:update_grade)
          .with(course.canvas_course_id, canvas_assignment_id, user.canvas_user_id, grade_breakdown.total_score)
          .once
        run_service
      end

      # We only want to mark them as new == false when they are successfully sent to Canvas.
      it 'marks interactions as graded' do
        # Stick a random ungraded interaction in there so we can see that it's set to graded after.
        create(:ungraded_progressed_module_interaction,
          canvas_course_id: course.canvas_course_id,
          user: user,
          canvas_assignment_id: canvas_assignment_id,
          progress: 50,
        )

        # Verify all interactions are marked as old after running the service
        interactions = Rise360ModuleInteraction.where(user: user, canvas_assignment_id: canvas_assignment_id, new: true)
        expect(interactions.count).to eq(1)

        run_service

        interactions.reload.each do |interaction|
          expect(interaction.new).to eq(false)
        end
      end

      context 'when module completion reaches 100% before the due date' do
        let(:on_time_grade) { 100 }
        # We need to cache this so that we can re-grade them if they get a due date extension
        it 'caches their on-time grade' do
          expect{ run_service }.to change{ rise360_module_grade.reload.on_time_credit_received }.from(false).to(true)
        end
      end
    end

    context 'when needs grading' do
      before(:each) do
        allow(grade_service).to receive(:needs_grading?).and_return(true)
      end

      context 'when run in nightly sync' do
        let(:force_computation) { false }
        let(:send_grade_to_canvas) { false }
        let(:canvas_submission_param) { canvas_submission }

        before(:each) do
          # The nightly sync gets the submissions in bulk and passes them in for performance reasons.
          # Make sure it's not calling the API by explicitly calling grade_is_manually_overridden? which
          # depends on the submission. Needed b/c grading_needed? is stubbed out.
          expect(canvas_client).not_to receive(:get_latest_submission)
          grade_service.grade_is_manually_overridden?
        end

        it_behaves_like 'grade computed'
        it_behaves_like 'grade not sent to canvas'
      end

      context 'when run on 100 percent module completion' do
        let(:force_computation) { false }
        let(:send_grade_to_canvas) { true }
        let(:canvas_submission_param) { nil }

        it_behaves_like 'grade computed'
        it_behaves_like 'grade sent to canvas'
      end

      context 'when run by viewing the grade breakdown page' do
        let(:force_computation) { true }
        let(:send_grade_to_canvas) { true }
        let(:canvas_submission_param) { nil }

        it_behaves_like 'grade computed'
        it_behaves_like 'grade sent to canvas'
      end
    end

    context 'when does not need grading' do
      before(:each) do
        allow(grade_service).to receive(:needs_grading?).and_return(false)
      end

      context 'when run in nightly sync' do
        let(:force_computation) { false }
        let(:send_grade_to_canvas) { false }
        let(:canvas_submission_param) { canvas_submission }

        before(:each) do
          # The nightly sync gets the submissions in bulk and passes them in for performance reasons.
          # Make sure it's not calling the API by explicitly calling grade_is_manually_overridden? which
          # depends on the submission. Needed b/c grading_needed? is stubbed out.
          expect(canvas_client).not_to receive(:get_latest_submission)
          grade_service.grade_is_manually_overridden?
        end

        it_behaves_like 'grade not computed'
        it_behaves_like 'grade not sent to canvas'
      end

      context 'when run on 100 percent module completion' do
        let(:force_computation) { false }
        let(:send_grade_to_canvas) { true }
        let(:canvas_submission_param) { nil }

        it_behaves_like 'grade not computed'
        it_behaves_like 'grade not sent to canvas'
      end

      # We ignore needs_grading? when explicitly viewing the grade breakdown b/c we
      # need the actual breakdown for display purposes.
      context 'when run by viewing the grade breakdown page' do
        let(:force_computation) { true }
        let(:send_grade_to_canvas) { true }
        let(:canvas_submission_param) { nil }

        it_behaves_like 'grade computed'
        it_behaves_like 'grade sent to canvas'
      end
    end

  end # run()

  # The tests below are for the core logic that determines whether we need to run the expensive grade
  # computation b/c the grade "could" change and need to be updated in Canvas. Note that the '#run'
  # tests handle that logic of only sending higher grades to Canvas.
  describe '#needs_grading?' do

    shared_examples 'needs grading' do
      it 'returns true' do
        expect(grade_service.needs_grading?).to eq(true)
      end
    end

    shared_examples 'does not need grading' do
      it 'returns false' do
        expect(grade_service.needs_grading?).to eq(false)
      end
    end

    shared_examples 'grade manually overidden' do
      let(:manual_grader_id) { canvas_api_user_id + 1 } # just needs to be different from the api user id
      let(:grader_id) { manual_grader_id }

      # Since we need to determine if staff accidentally gave a lower grade, we always re-grade
      # manually graded submissions in case we need to send a higher grade and revert to auto-grading.
      it 'returns true' do
        expect(grade_service.needs_grading?).to eq(true)
      end
    end

    # Tests for when they've never opened the Module
    context 'when no interactions' do
      let(:canvas_submission) { create :canvas_submission_placeholder, cached_due_date: due_date }

      it_behaves_like 'does not need grading'

      context 'with due date in past' do
        let(:due_date) { (Time.now - 1.week).utc.iso8601 }

        # Need to send 0 grade to Canvas
        it_behaves_like 'needs grading'
      end
    end

    # Tests for when they've done new work in the Module since the last time
    # grading ran and we successfully sent the new grade to Canvas
    context 'when new interactions' do

      let!(:new_interactions) { [
        create(:ungraded_progressed_module_interaction,
          canvas_course_id: course.canvas_course_id,
          user: user,
          canvas_assignment_id: canvas_assignment_id,
          progress: 50,
        ),
        create(:ungraded_answered_module_interaction,
          canvas_course_id: course.canvas_course_id,
          user: user,
          canvas_assignment_id: canvas_assignment_id,
          success: true,
        )]
      }

      # Stick one of the old ones in there just to be safe
      let!(:old_interaction) {
        create(:graded_progressed_module_interaction,
          canvas_course_id: course.canvas_course_id,
          user: user,
          canvas_assignment_id: canvas_assignment_id,
          progress: 33,
          new: false,
        )
      }

      context 'when Module not complete' do
        it_behaves_like 'needs grading'
        it_behaves_like 'grade manually overidden'
      end

      context 'when Module complete' do
        let!(:completed_interaction) {
          create(:ungraded_progressed_module_interaction,
            canvas_course_id: course.canvas_course_id,
            user: user,
            canvas_assignment_id: canvas_assignment_id,
            progress: 100,
          )
        }

        it_behaves_like 'needs grading'
        it_behaves_like 'grade manually overidden'
      end

    end

    # Tests for when all their work has already been graded and sent to Canvas.
    context 'when only old interactions' do

      let!(:old_interactions) { [
        create(:graded_progressed_module_interaction,
          canvas_course_id: course.canvas_course_id,
          user: user,
          canvas_assignment_id: canvas_assignment_id,
          progress: 50,
          new: false,
        ),
        create(:graded_answered_module_interaction,
          canvas_course_id: course.canvas_course_id,
          user: user,
          canvas_assignment_id: canvas_assignment_id,
          success: true,
          new: false,
        )]
      }

      context 'when Module not complete' do
        it_behaves_like 'does not need grading'
        it_behaves_like 'grade manually overidden'
      end

      context 'when Module complete' do
        let!(:completed_interaction) {
          create(:graded_progressed_module_interaction,
            canvas_course_id: course.canvas_course_id,
            user: user,
            canvas_assignment_id: canvas_assignment_id,
            progress: 100,
            new: false
          )
        }
        # When we grade a completed module on-time, we cache that value to avoid
        # re-grading. This puts the cached value in place.
        let(:on_time_credit_received) { true }
        let!(:the_rise360_module_grade) { rise360_module_grade }

        it_behaves_like 'does not need grading'
        it_behaves_like 'grade manually overidden'

        context 'when extension given' do
          let(:on_time_credit_received) { false }

          it_behaves_like 'needs grading'

          context 'when still not completed on time' do
            let(:due_date) { (Time.now - 1.day).utc.iso8601 }
            it_behaves_like 'does not need grading'
          end
        end
      end
    end

  end # needs_grading?

end
