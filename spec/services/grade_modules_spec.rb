# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GradeModules do

  let(:grade_modules) { GradeModules.new }
  let(:sf_client) { double(SalesforceAPI) }
  # Default: no programs. Override in context below where appropriate.
  let(:sf_programs) { create(:salesforce_current_and_future_programs) }
  let(:canvas_client) { double(CanvasAPI) }

  describe "#run" do
    subject { grade_modules.run }

    context "with no running programs" do
      before :each do
        allow(grade_modules).to receive(:grade_course).and_return(nil)

        allow(sf_client)
          .to receive(:get_current_and_future_accelerator_programs)
          .and_return(sf_programs)
        allow(SalesforceAPI).to receive(:client).and_return(sf_client)
      end

      it "exits early" do
        # Stub Course.where so we can check if it was called.
        allow(Course).to receive(:where)

        subject

        expect(sf_client).to have_received(:get_current_and_future_accelerator_programs)
        # We should exit before Course.where gets called.
        expect(Course).not_to have_received(:where)
      end
    end

    context "with some running programs" do
      let(:course) { create(:course) }
      let(:sf_programs) { create(:salesforce_current_and_future_programs, canvas_course_ids: [course.canvas_course_id]) }

      context "with no interactions that match the courses" do
        before :each do
          allow(grade_modules).to receive(:grade_course).and_return(nil)

          allow(sf_client)
            .to receive(:get_current_and_future_accelerator_programs)
            .and_return(sf_programs)
          allow(SalesforceAPI).to receive(:client).and_return(sf_client)

          # Create some non-matching interactions.
          create(:progressed_module_interaction, canvas_course_id: course.canvas_course_id + 1)
          create(:progressed_module_interaction, canvas_course_id: course.canvas_course_id + 1)
        end

        it "exits early" do
          subject

          expect(sf_client).to have_received(:get_current_and_future_accelerator_programs)
          # We should exit before grade_course gets called.
          expect(grade_modules).not_to have_received(:grade_course)
        end
      end

      context "with interactions that match the courses" do
        # Two running programs, two courses, arbitrary Canvas IDs.
        let(:course1) { create(:course, canvas_course_id: 55) }
        let(:course2) { create(:course, canvas_course_id: 56) }
        let(:course3) { create(:course, canvas_course_id: 57) }
        let(:sf_programs) { create(:salesforce_current_and_future_programs,
          canvas_course_ids: [
            course1.canvas_course_id,
            course2.canvas_course_id,
            course3.canvas_course_id,
          ]
        ) }
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
            .to receive(:get_current_and_future_accelerator_programs)
            .and_return(sf_programs)
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
    subject { grade_modules.grade_assignment(canvas_assignment_id, user_ids) }

    let(:course) { create(:course) }
    let(:section) { create(:section, course: course) }
    # Arbitrary Canvas IDs.
    let!(:user_with_new_interactions) { create(:fellow_user, section: section, canvas_user_id: 1) }
    let!(:user_with_old_interactions) { create(:fellow_user, section: section, canvas_user_id: 2) }
    let!(:module_with_interactions) { create(:course_rise360_module_version, course: course) }
    let!(:module_without_interactions) { create(:course_rise360_module_version, course: course) }
    let!(:module_grade_for_user_with_new_interactions) {
      create :rise360_module_grade, course_rise360_module_version: module_with_interactions, user: user_with_new_interactions
    }
    let!(:module_grade_for_user_with_old_interactions) {
      create :rise360_module_grade, course_rise360_module_version: module_with_interactions, user: user_with_old_interactions
    }
    let(:course_rise360_module_versions) { [
      module_with_interactions,
      module_without_interactions,
    ] }
    let!(:interactions) { [
      # user_with_new_interactions
      create(:ungraded_progressed_module_interaction,
        canvas_course_id: course.canvas_course_id,
        user: user_with_new_interactions,
        canvas_assignment_id: user_with_new_interactions_assignment_id,
        progress: 50,
      ),
      create(:ungraded_progressed_module_interaction,
        canvas_course_id: course.canvas_course_id,
        user: user_with_new_interactions,
        canvas_assignment_id: user_with_new_interactions_assignment_id,
        progress: 100,
      ),
      create(:ungraded_answered_module_interaction,
        canvas_course_id: course.canvas_course_id,
        user: user_with_new_interactions,
        canvas_assignment_id: user_with_new_interactions_assignment_id,
        success: true,
      ),
      # user_with_old_interactions
      create(:graded_progressed_module_interaction,
        canvas_course_id: course.canvas_course_id,
        user: user_with_old_interactions,
        canvas_assignment_id: user_with_old_interactions_assignment_id,
        progress: 50,
        new: false,
      ),
      create(:graded_progressed_module_interaction,
        canvas_course_id: course.canvas_course_id,
        user: user_with_old_interactions,
        canvas_assignment_id: user_with_old_interactions_assignment_id,
        progress: 100,
      ),
      create(:graded_answered_module_interaction,
        canvas_course_id: course.canvas_course_id,
        user: user_with_old_interactions,
        canvas_assignment_id: user_with_old_interactions_assignment_id,
        success: true,
      ),
    ] }
    # Defaults. Override in context below.
    let(:user_ids) { [ user_with_old_interactions.id ] }
    let(:user_with_new_interactions_assignment_id) { module_with_interactions.canvas_assignment_id }
    let(:user_with_old_interactions_assignment_id) { module_with_interactions.canvas_assignment_id }
    let(:canvas_assignment_id) { module_without_interactions.canvas_assignment_id }
    let(:due_date_obj) { 1.day.from_now.utc }
    let(:due_date) { due_date_obj.to_time.iso8601 }
    let(:assignment_overrides) { [] }

    context "with no matching interactions for assignment" do
      before :each do
        allow(canvas_client).to receive(:get_assignment_overrides)
        allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      end

      it "exits early" do
        subject

        # Should exit before get_assignment_overrides call.
        expect(canvas_client).not_to have_received(:get_assignment_overrides)
      end
    end

    context "with matching interactions for assignment" do
      let(:canvas_assignment_id) { module_with_interactions.canvas_assignment_id }
      let(:manually_graded) { false }

      shared_examples "runs pre-compute tasks" do
        before :each do
          allow(canvas_client).to receive(:get_assignment_overrides).and_return(assignment_overrides)
          allow(canvas_client).to receive(:latest_submission_manually_graded?).and_return(manually_graded)
          allow(canvas_client).to receive(:update_grades)
          allow(CanvasAPI).to receive(:client).and_return(canvas_client)

          allow(ModuleGradeCalculator).to receive(:compute_grade)
          allow(ModuleGradeCalculator).to receive(:due_date_for_user).and_return(due_date)
        end

        context "when grades manually overridden" do
          let(:manually_graded) { true }

          it "skips users" do
            subject

            expect(ModuleGradeCalculator).not_to have_received(:due_date_for_user)
            expect(ModuleGradeCalculator).not_to have_received(:compute_grade)
          end
        end

        context "when grades not manually overridden" do
          let(:manually_graded) { false }

          it "calls due_date_for_user correctly for each user" do
            subject

            expect(ModuleGradeCalculator)
              .to have_received(:due_date_for_user)
              .exactly(user_ids.count)
              .times
            user_ids.each do |user_id|
              expect(ModuleGradeCalculator)
                .to have_received(:due_date_for_user)
                .with(user_id, assignment_overrides)
            end
          end
        end
      end

      shared_examples "computes and updates grades" do
        before :each do
          allow(canvas_client).to receive(:get_assignment_overrides).and_return(assignment_overrides)
          allow(canvas_client).to receive(:latest_submission_manually_graded?)
          allow(canvas_client).to receive(:update_grades)
          allow(CanvasAPI).to receive(:client).and_return(canvas_client)

          allow(ModuleGradeCalculator).to receive(:due_date_for_user).and_return(due_date)
        end

        it "calls compute_grade correctly for each user" do
          allow(ModuleGradeCalculator).to receive(:compute_grade)

          subject

          expect(ModuleGradeCalculator)
            .to have_received(:compute_grade)
            .exactly(user_ids.count)
            .times
          user_ids.each do |user_id|
            expect(ModuleGradeCalculator)
              .to have_received(:compute_grade)
              .with(user_id, canvas_assignment_id, assignment_overrides)
          end
        end

        it "computes the correct grades" do
          expected_grade = '30.0'
          allow(ModuleGradeCalculator).to receive(:compute_grade).and_return(expected_grade)

          subject

          grades = {}
          user_ids.each do |user_id|
            grades[User.find(user_id).canvas_user_id] = "#{expected_grade}%"
          end
          expect(canvas_client)
            .to have_received(:update_grades)
            .with(course.canvas_course_id, canvas_assignment_id, grades)
        end

        it "calls update_grades once" do
          subject

          expect(canvas_client).to have_received(:update_grades).once
        end

        it "marks matching interactions as old" do
          subject

          # Verify we only have matching interactions pre-max_id.
          expect(Rise360ModuleInteraction.all.count).to eq(interactions.count)
          # Verify all interactions are marked as old.
          Rise360ModuleInteraction.where(user_id: user_ids).each do |interaction|
            expect(interaction.new).to eq(false)
          end
        end
      end

      context "with no new interactions for user, running before due_date" do

        it_behaves_like "runs pre-compute tasks"

        it "exits early" do
          allow(canvas_client).to receive(:get_assignment_overrides).and_return(assignment_overrides)
          allow(canvas_client).to receive(:latest_submission_manually_graded?)
          allow(CanvasAPI).to receive(:client).and_return(canvas_client)

          allow(ModuleGradeCalculator).to receive(:compute_grade)
          allow(ModuleGradeCalculator).to receive(:due_date_for_user).and_return(due_date)
          puts "due_date here #{due_date}"

          subject

          expect(ModuleGradeCalculator).not_to have_received(:compute_grade)
        end
      end

      context "with no new interactions for user, running after due_date" do
        let(:due_date_obj) { -3.days.from_now.utc }

        it_behaves_like "runs pre-compute tasks"

        it_behaves_like "computes and updates grades"
      end

      context "with new interactions for user" do
        let(:user_ids) { [ user_with_new_interactions.id ] }

        it_behaves_like "runs pre-compute tasks"

        it_behaves_like "computes and updates grades"
      end
    end

  end  # grade_assignment

  describe ".grading_disabled_for?" do
    let(:user) { create(:fellow_user) }
    let(:canvas_assignment_id) { course_rise360_module_version.canvas_assignment_id }
    let(:canvas_course_id) { course_rise360_module_version.course.canvas_course_id }
    let(:course_rise360_module_version) { create :course_rise360_module_version }

    subject { GradeModules.grading_disabled_for?(canvas_course_id, canvas_assignment_id, user) }

    before :each do
       allow(canvas_client).to receive(:latest_submission_manually_graded?)
       allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    end

    context "when user has never opened the module" do
      it "returns true" do
        expect(subject).to eq(true)
      end

      it "doesn't hit the Canvas API" do
        subject
        expect(canvas_client).not_to have_received(:latest_submission_manually_graded?)
      end

      it "doesn't create a Rise360ModuleGrade" do
        expect{subject}.to change(Rise360ModuleGrade, :count).by(0)
      end
    end

    context "when not manually overridden" do
      let!(:rise360_module_grade) { create :rise360_module_grade, user: user, course_rise360_module_version: course_rise360_module_version }

      before(:each) do
        allow(canvas_client).to receive(:latest_submission_manually_graded?).and_return(false)
      end

      it "returns false" do
        expect(subject).to eq(false)
      end

      it "hits the Canvas API to check" do
        subject
        expect(canvas_client).to have_received(:latest_submission_manually_graded?).once
      end
    end

    context "when detecting manual override" do
      let!(:rise360_module_grade) { create :rise360_module_grade, user: user, course_rise360_module_version: course_rise360_module_version }

      before(:each) do
        allow(canvas_client).to receive(:latest_submission_manually_graded?).and_return(true)
      end

      it "returns true" do
        expect(subject).to eq(true)
      end

      it "hits the Canvas API to check" do
        subject
        expect(canvas_client).to have_received(:latest_submission_manually_graded?).once
      end
    end

    context "when already manually overridden in the past" do
      let!(:rise360_module_grade) { create :rise360_module_grade_overridden, user: user, course_rise360_module_version: course_rise360_module_version }

      it "returns true" do
        expect(subject).to eq(true)
      end

      it "doesn't hit the Canvas API" do
        subject
        expect(canvas_client).not_to have_received(:latest_submission_manually_graded?)
      end
    end

  end

end
