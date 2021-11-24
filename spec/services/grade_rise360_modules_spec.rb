# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GradeRise360Modules do

  let(:grade_modules) { GradeRise360Modules.new }
  let(:sf_client) { double(SalesforceAPI) }
  # Default: no courses. Override in context below where appropriate.
  let(:accelerator_course_ids) { [] }
  let(:canvas_client) { double(CanvasAPI) }

  describe "#run" do
    subject { grade_modules.run }

    context "with no running programs" do
      before :each do
        allow(grade_modules).to receive(:grade_course).and_return(nil)

        allow(sf_client)
          .to receive(:get_current_and_future_accelerator_canvas_course_ids)
          .and_return(accelerator_course_ids)
        allow(SalesforceAPI).to receive(:client).and_return(sf_client)
      end

      it "exits early" do
        # Stub Course.where so we can check if it was called.
        allow(Course).to receive(:where)

        subject

        expect(sf_client).to have_received(:get_current_and_future_accelerator_canvas_course_ids)
        # We should exit before Course.where gets called.
        expect(Course).not_to have_received(:where)
      end
    end

    context "with some running programs" do
      let(:course) { create(:course) }
      let(:accelerator_course_ids) { [course.canvas_course_id] }

      context "with no interactions that match the courses" do
        before :each do
          allow(grade_modules).to receive(:grade_course).and_return(nil)

          allow(sf_client)
            .to receive(:get_current_and_future_accelerator_canvas_course_ids)
            .and_return(accelerator_course_ids)
          allow(SalesforceAPI).to receive(:client).and_return(sf_client)

          # Need to freeze now so that it matches
          allow(Time).to receive(:now).and_return(Time.now)

          # Create some non-matching interactions.
          create(:progressed_module_interaction, canvas_course_id: course.canvas_course_id + 1)
          create(:progressed_module_interaction, canvas_course_id: course.canvas_course_id + 1)
        end

        # https://app.asana.com/0/1201131148207877/1200788567441198
        it 'also gets programs that ended in the past 45 days' do
          expect(sf_client)
            .to receive(:get_current_and_future_accelerator_canvas_course_ids)
            .with(ended_less_than: 45.days.ago)
            .and_return(accelerator_course_ids)
          subject
        end

        it "exits early" do
          subject

          expect(sf_client).to have_received(:get_current_and_future_accelerator_canvas_course_ids)
          # We should exit before grade_course gets called.
          expect(grade_modules).not_to have_received(:grade_course)
        end
      end

      context "with interactions that match the courses" do
        # Two running programs, two courses, arbitrary Canvas IDs.
        let(:course1) { create(:course, canvas_course_id: 55) }
        let(:course2) { create(:course, canvas_course_id: 56) }
        let(:course3) { create(:course, canvas_course_id: 57) }
        let(:accelerator_course_ids) {
          [
            course1.canvas_course_id,
            course2.canvas_course_id,
            course3.canvas_course_id,
          ]
        }
        # Be sure to adjust this if you change `interactions` below.
        let(:courses_with_interactions) { [course1, course2] }
        # Create some matching interactions for the courses.
        let!(:interactions) { [
          create(:progressed_module_interaction, canvas_course_id: course1.canvas_course_id),
          create(:progressed_module_interaction, canvas_course_id: course1.canvas_course_id),
          create(:progressed_module_interaction, canvas_course_id: course2.canvas_course_id),
        ] }

        before :each do
          allow(grade_modules).to receive(:grade_course).and_return(nil)

          allow(sf_client)
            .to receive(:get_current_and_future_accelerator_canvas_course_ids)
            .and_return(accelerator_course_ids)
          allow(SalesforceAPI).to receive(:client).and_return(sf_client)
        end

        it "calls grade_course once for each course with interactions" do
          subject

          expect(grade_modules)
            .to have_received(:grade_course)
            .exactly(courses_with_interactions.count)
            .times
        end

        it "doesn't call grade_course for courses that have no interactions" do
          subject

          expect(grade_modules)
            .not_to have_received(:grade_course)
            .with(course3)
        end
      end
    end
  end  # run

  describe "#grade_course" do
    subject { grade_modules.grade_course(course) }

    let(:course) { create(:course) }

    context "with no sections in course" do
      # Create one assignment, so we can check grade_assignment calls.
      let!(:course_rise360_module_version) { create(:course_rise360_module_version,
        course: course
      ) }
      let(:canvas_assignment_id) {
        course_rise360_module_version.canvas_assignment_id
      }

      before :each do
        allow(grade_modules).to receive(:grade_assignment).and_return(nil)
      end

      it "gets empty user_ids" do
        subject

        expect(grade_modules)
          .to have_received(:grade_assignment)
          .with(canvas_assignment_id, [])
      end
    end

    context "with no enrolled users in course" do
      # Create one assignment, so we can check grade_assignment calls.
      let!(:course_rise360_module_version) { create(:course_rise360_module_version,
        course: course
      ) }
      let(:canvas_assignment_id) {
        course_rise360_module_version.canvas_assignment_id
      }
      let!(:section) { create(:section, course: course) }

      before :each do
        allow(grade_modules).to receive(:grade_assignment).and_return(nil)
      end

      it "gets empty user_ids" do
        subject

        expect(grade_modules)
          .to have_received(:grade_assignment)
          .with(canvas_assignment_id, [])
      end
    end

    context "with no module versions in course" do
      before :each do
        allow(grade_modules).to receive(:grade_assignment).and_return(nil)
      end

      it "gets empty canvas_assignment_ids" do
        subject

        expect(grade_modules)
          .not_to have_received(:grade_assignment)
      end
    end

    context "with proper setup" do
      # Set up users and assignments.
      let!(:course_rise360_module_versions) { [
        create(:course_rise360_module_version, course: course),
        create(:course_rise360_module_version, course: course),
      ] }
      let(:section1) { create(:section, course: course) }
      let(:section2) { create(:section, course: course) }
      let!(:users) { [
        # Arbitrary Canvas user IDs.
        create(:fellow_user, section: section1, canvas_user_id: 1),
        create(:fellow_user, section: section1, canvas_user_id: 2),
        create(:fellow_user, section: section2, canvas_user_id: 3),
      ] }
      # Add users not in this course, just to be sure we're selecting the
      # right things.
      let(:course2) { create(:course) }
      let(:section3) { create(:section, course: course2) }
      let!(:not_this_user) { create(:fellow_user, section: section3, canvas_user_id: 4) }

      before :each do
        allow(grade_modules).to receive(:grade_assignment).and_return(nil)
      end

      it "calls grade_assignment once for each assignment with correct user_ids" do
        subject

        expect(grade_modules)
          .to have_received(:grade_assignment)
          .exactly(course_rise360_module_versions.count)
          .times
        course_rise360_module_versions.each do |crmv|
          expect(grade_modules)
            .to have_received(:grade_assignment)
            .with(crmv.canvas_assignment_id, users.map { |u| u.id })
        end
      end
    end
  end  # grade_course

  describe "#grade_assignment" do
    let(:course) { create(:course) }
    let(:section) { create(:section, course: course) }
    let!(:user_with_new_interactions) { create(:fellow_user, section: section) }
    let!(:user_with_no_interactions) { create(:fellow_user, section: section) }
    # We process all StudentEnrollments in the course
    let!(:user_ids) { [ user_with_new_interactions.id, user_with_no_interactions.id ] }
    let!(:module_with_interactions) { create(:course_rise360_module_version, course: course) }
    let!(:module_without_interactions) { create(:course_rise360_module_version, course: course) }
    let!(:module_grade_for_user_with_new_interactions) {
      create :rise360_module_grade, course_rise360_module_version: module_with_interactions, user: user_with_new_interactions
    }
    let(:course_rise360_module_versions) { [
      module_with_interactions,
      module_without_interactions,
    ] }
    let(:canvas_submission_for_user_with_new_interactions) {
      create :canvas_submission_rise360_module_opened,
        user_id: user_with_new_interactions.canvas_user_id,
        assignment_id: canvas_assignment_id
    }
    let(:canvas_submission_for_user_with_no_interactions) {
      create :canvas_submission_placeholder,
        user_id: user_with_no_interactions.canvas_user_id,
        assignment_id: canvas_assignment_id
    }
    let(:canvas_submissions) {
      {
        user_with_new_interactions.canvas_user_id => canvas_submission_for_user_with_new_interactions,
        user_with_no_interactions.canvas_user_id => canvas_submission_for_user_with_no_interactions
      }
    }
    # We need at least one interaction for a module in order for grading to run.
    # This allows us to skip grading for things that no one has touched.
    let!(:interaction) {
      create(:ungraded_progressed_module_interaction,
        canvas_course_id: course.canvas_course_id,
        user: user_with_new_interactions,
        canvas_assignment_id: module_with_interactions.canvas_assignment_id,
        progress: 50,
      )
    }
    let(:grade_breakdown_zero) { ComputeRise360ModuleGrade::ComputedGradeBreakdown.new(0,0,0) }
    let(:grade_breakdown_partial) { ComputeRise360ModuleGrade::ComputedGradeBreakdown.new(50,0,0) }
    let(:grade_breakdown_completed_on_time) { ComputeRise360ModuleGrade::ComputedGradeBreakdown.new(100,0,100,Time.now.utc) }
    let(:grade_breakdown_completed_late) { ComputeRise360ModuleGrade::ComputedGradeBreakdown.new(100,0,0,Time.now.utc) }

    # Defaults. Override in context below.
    let(:canvas_assignment_id) { module_without_interactions.canvas_assignment_id }

    subject { grade_modules.grade_assignment(canvas_assignment_id, user_ids) }

    before :each do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(canvas_client).to receive(:get_assignment_submissions)
    end

    context "with no matching interactions for assignment" do
      let(:canvas_assignment_id) { module_without_interactions.canvas_assignment_id }
      let(:grading_service) { double(GradeRise360ModuleForUser) }

      # Note: We have this "exits early" code in place b/c we're running the sync for every current
      # and future program and it would be really expensive to loop through ALL assignments.
      it "exits early" do
        allow(GradeRise360ModuleForUser).to receive(:new).and_return(grading_service)
        allow(grading_service).to receive(:run)

        subject

        # Should exit before get_assignment_submissions call.
        expect(canvas_client).not_to have_received(:get_assignment_submissions)
        expect(grading_service).not_to have_received(:run)
      end
    end

    context "with matching interactions for assignment" do
      let(:canvas_assignment_id) { module_with_interactions.canvas_assignment_id }
      let(:grading_service) { double(GradeRise360ModuleForUser) }

      before :each do
        expect(canvas_client).to receive(:get_assignment_submissions)
          .with(course.canvas_course_id, canvas_assignment_id)
          .and_return(canvas_submissions)
        allow(canvas_client).to receive(:update_grades)
        allow(GradeRise360ModuleForUser).to receive(:new).and_return(grading_service)
      end

      it "calls GradeRise360ModuleForUser#run correctly for each user" do
        allow(grading_service).to receive(:run)
        allow(grading_service).to receive(:grade_changed?)

        subject

        user_ids.each do |user_id|
          user = User.find(user_id)
          expect(GradeRise360ModuleForUser)
            .to have_received(:new)
            .with(user, module_with_interactions, false, false, canvas_submissions[user.canvas_user_id])
            .once
        end
        expect(grading_service)
          .to have_received(:run)
          .exactly(user_ids.count)
          .times
      end

      context "with no grade changes" do
        it "exits early" do
          allow(grading_service).to receive(:run).and_return(nil)
          allow(grading_service).to receive(:grade_changed?).and_return(false)

          subject

          expect(canvas_client).not_to have_received(:update_grades)
        end
      end

      shared_examples "sends grades to Canvas" do

        it "calls update_grades once" do
          subject
          expect(canvas_client).to have_received(:update_grades).once
        end

        it "marks matching interactions as old" do

          # Add an interaction for a different canvas_assignment_id to make sure it's not touched
          create(:ungraded_progressed_module_interaction,
            canvas_course_id: course.canvas_course_id,
            user: user_with_new_interactions,
            canvas_assignment_id: canvas_assignment_id + 1,
            progress: 50,
            new: true
          )

          # Sanity check that we have all new interactions
          Rise360ModuleInteraction.where(user_id: user_ids).each do |interaction|
            expect(interaction.new).to eq(true)
          end

          subject

          Rise360ModuleInteraction.where(user_id: user_ids).each do |interaction|
            expect(interaction.new).to eq(false) if interaction.canvas_assignment_id == canvas_assignment_id
            expect(interaction.new).to eq(true) if interaction.canvas_assignment_id != canvas_assignment_id
          end
        end

      end # "sends grades to Canvas"

      context "with grade changes" do
        let(:grade_breakdown1) { nil }
        let(:grade_breakdown2) { nil }
        let(:grade_for_canvas1) { grade_breakdown1.total_score if grade_breakdown1 }
        let(:grade_for_canvas2) { grade_breakdown2.total_score if grade_breakdown2 }
        let(:grading_service_for_user1) {
          double(GradeRise360ModuleForUser,
            :run => grade_for_canvas1,
            :computed_grade_breakdown => grade_breakdown1
          )
        }
        let(:grading_service_for_user2) {
          double(GradeRise360ModuleForUser,
            :run => grade_for_canvas2,
            :computed_grade_breakdown => grade_breakdown2
          )
        }

        before(:each) do
          expect(GradeRise360ModuleForUser).to receive(:new)
            .with(user_with_new_interactions, module_with_interactions, anything, anything, anything)
            .and_return(grading_service_for_user1)
          expect(GradeRise360ModuleForUser).to receive(:new)
            .with(user_with_no_interactions, module_with_interactions, anything, anything, anything)
            .and_return(grading_service_for_user2)
        end

        context "for only 1 user" do
          let(:grade_breakdown1) { grade_breakdown_partial }

          before(:each) do
            allow(grading_service_for_user1).to receive(:grade_changed?).and_return(true)
            allow(grading_service_for_user2).to receive(:grade_changed?).and_return(false)
          end

          it_behaves_like "sends grades to Canvas"

          it "only sends grades to Canvas for the changed grade" do
            subject
            expect(canvas_client).to have_received(:update_grades)
              .with(course.canvas_course_id, canvas_assignment_id, {user_with_new_interactions.canvas_user_id => grade_for_canvas1})
              .once
          end

          context "when completed_at before due date" do
            let(:grade_breakdown1) { grade_breakdown_completed_on_time }
            it "caches the on_time_credit_received value" do
              allow(grading_service_for_user1).to receive(:rise360_module_grade).and_return(module_grade_for_user_with_new_interactions)
              expect{ subject }.to change{ module_grade_for_user_with_new_interactions.reload.on_time_credit_received }
                .from(false).to(true)
            end
          end

          context "when completed_at after due date" do
            let(:grade_breakdown1) { grade_breakdown_completed_late }
            it "does not cache the on_time_credit_received value" do
              expect{ subject }.not_to change{ module_grade_for_user_with_new_interactions.reload.on_time_credit_received }
            end
          end
        end

        context "for both users" do
          let(:grade_breakdown1) { grade_breakdown_partial }
          let(:grade_breakdown2) { grade_breakdown_zero } # Mimic a zero grade being sent after due date passes.

          before(:each) do
            allow(grading_service_for_user1).to receive(:grade_changed?).and_return(true)
            allow(grading_service_for_user2).to receive(:grade_changed?).and_return(true)
          end

          it_behaves_like "sends grades to Canvas"

          it "sends grades to Canvas for the changed grades" do
            subject
            expect(canvas_client).to have_received(:update_grades)
              .with(course.canvas_course_id, canvas_assignment_id,
                {
                  user_with_new_interactions.canvas_user_id => grade_for_canvas1,
                  user_with_no_interactions.canvas_user_id => grade_for_canvas2,
                }
              ).once
          end
        end

      end # "with grade changes"

    end # "with matching interactions for assignment"

  end  # grade_assignment

end
