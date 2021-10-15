require 'rails_helper'

RSpec.describe ComputeRise360ModuleGrade do

  let(:activity_id) { 'someactivityid' }
  let(:course) { create(:course) }
  let(:section) { create(:section_with_canvas_id, course: course) }
  let(:user) { create(:fellow_user, section: section) }
  let(:rise360_module_version) { create(:rise360_module_version) }
  let(:course_rise360_module_version) { create(:course_rise360_module_version,
    course: course,
    rise360_module_version: rise360_module_version,
  ) }
  let(:canvas_assignment_id) { course_rise360_module_version.canvas_assignment_id }
  # This is the format Canvas sends. E.g. 2021-08-14T03:59:59Z
  let(:due_date) { (Time.now.utc + 1.week).iso8601 }
  let(:compute_service) { ComputeRise360ModuleGrade.new(user, course_rise360_module_version, due_date) }

  describe "GRADE_WEIGHTS" do
    it "sums up to 1" do
      total = 0.0
      ComputeRise360ModuleGrade::GRADE_WEIGHTS.each do |key, weight|
        total += weight
      end
      expect(total).to eq(1.0)
    end
  end  # grade_weights

  describe "#run" do
    context "empty Rise360ModuleInteraction table" do
      it "returns 0" do
        interactions = Rise360ModuleInteraction.where(new: true)
        expect(interactions).to be_empty

        grade = compute_service.run()
        expect(grade).to eq(ComputeRise360ModuleGrade::ComputedGradeBreakdown.new(0,0,0))
      end
    end

    context "with 100s for everything" do
      # Need a new interaction to trigger computation
      let!(:completed_interaction) {
        Rise360ModuleInteraction.create!(
          verb: Rise360ModuleInteraction::PROGRESSED,
          user: user,
          canvas_course_id: 333,
          canvas_assignment_id: canvas_assignment_id,
          activity_id: activity_id,
          progress: 100,
          new: true,
        )
      }

      before :each do
        # Stub out grade computation
        allow(compute_service)
          .to receive(:grade_mastery_quiz)
          .and_return(100)
        allow(compute_service)
          .to receive(:grade_module_engagement)
          .and_return(completed_interaction.progress)
        allow(compute_service)
          .to receive(:grade_completed_on_time)
          .and_return(100)
      end

      it "grades engagement and quiz" do
        grade = compute_service.run()

        # Called each grading method
        expect(compute_service)
          .to have_received(:grade_module_engagement)
          .once
        expect(compute_service)
          .to have_received(:grade_mastery_quiz)
          .once

        # They get full credit
        expect(grade.total_score).to eq(Rise360Module::POINTS_POSSIBLE)
      end
    end

    context "with no quiz" do
      # Need a new interaction to trigger computation
      let!(:completed_interaction) {
        Rise360ModuleInteraction.create!(
          verb: Rise360ModuleInteraction::PROGRESSED,
          user: user,
          canvas_course_id: 333,
          canvas_assignment_id: canvas_assignment_id,
          activity_id: activity_id,
          progress: 100,
          new: true,
        )
      }

      before :each do
        # Stub out grade computation
        allow(rise360_module_version)
          .to receive(:quiz_questions)
          .and_return(0)
        allow(compute_service)
          .to receive(:grade_module_engagement)
          .and_return(completed_interaction.progress)
      end

      it "only grades engagement if no quiz" do
        # Test that the mastery part of grading is skipped
        expect(compute_service)
          .not_to receive(:grade_mastery_quiz)

        grade = compute_service.run()

        # Called each grading method
        expect(compute_service)
          .to have_received(:grade_module_engagement)
          .once

        # They get full credit
        expect(grade.total_score).to eq(Rise360Module::POINTS_POSSIBLE)
      end
    end

    context "with half scores for everything" do
      # Two total questions.
      let(:rise360_module_version) { create(:rise360_module_version, quiz_questions: 2) }

      before :each do
        # 50% progress.
        Rise360ModuleInteraction.create!(
          verb: Rise360ModuleInteraction::PROGRESSED,
          user: user,
          canvas_course_id: course.canvas_course_id,
          canvas_assignment_id: canvas_assignment_id,
          activity_id: activity_id,
          progress: 50,
          new: true,
        )

        # One correct, one incorrect.
        Rise360ModuleInteraction.create!(
          verb: Rise360ModuleInteraction::ANSWERED,
          user: user,
          canvas_course_id: 333,
          canvas_assignment_id: canvas_assignment_id,
          activity_id: "#{activity_id}/somequizid/firstquestion",
          success: true,
          new: true,
        )
        Rise360ModuleInteraction.create!(
          verb: Rise360ModuleInteraction::ANSWERED,
          user: user,
          canvas_course_id: 333,
          canvas_assignment_id: canvas_assignment_id,
          activity_id: "#{activity_id}/somequizid/secondquestion",
          success: false,
          new: true,
        )
      end

      it "computes the correct grade" do
        grade = compute_service.run()
        expect(grade.total_score).to eq( 0.5*4.0 + 0.5*4.0 + 0.0*2.0 )
      end
    end

    context "with all old interactions" do
      # Two total questions.
      let(:rise360_module_version) { create(:rise360_module_version, quiz_questions: 2) }

      before :each do
        # 50% progress.
        Rise360ModuleInteraction.create!(
          verb: Rise360ModuleInteraction::PROGRESSED,
          user: user,
          canvas_course_id: course.canvas_course_id,
          canvas_assignment_id: canvas_assignment_id,
          activity_id: activity_id,
          progress: 50,
          new: false,
        )

        # One correct, one incorrect.
        Rise360ModuleInteraction.create!(
          verb: Rise360ModuleInteraction::ANSWERED,
          user: user,
          canvas_course_id: 333,
          canvas_assignment_id: canvas_assignment_id,
          activity_id: "#{activity_id}/somequizid/firstquestion",
          success: true,
          new: false,
        )
        Rise360ModuleInteraction.create!(
          verb: Rise360ModuleInteraction::ANSWERED,
          user: user,
          canvas_course_id: 333,
          canvas_assignment_id: canvas_assignment_id,
          activity_id: "#{activity_id}/somequizid/secondquestion",
          success: false,
          new: false,
        )
      end

      it "still computes the correct grade" do
        grade = compute_service.run()
        expect(grade.total_score).to eq( 0.5*4.0 + 0.5*4.0 + 0.0*2.0 )
      end
    end

    context "with full engagement and partial mastery" do
      # Two total questions.
      let(:rise360_module_version) { create(:rise360_module_version, quiz_questions: 2) }

      let!(:completed_interaction) {
        Rise360ModuleInteraction.create!(
          verb: Rise360ModuleInteraction::PROGRESSED,
          user: user,
          canvas_course_id: 333,
          canvas_assignment_id: canvas_assignment_id,
          activity_id: activity_id,
          progress: 100,
          new: true,
        )
      }

      before :each do
        # One correct, one incorrect.
        Rise360ModuleInteraction.create!(
          verb: Rise360ModuleInteraction::ANSWERED,
          user: user,
          canvas_course_id: 333,
          canvas_assignment_id: canvas_assignment_id,
          activity_id: "#{activity_id}/somequizid/firstquestion",
          success: true,
          new: true,
        )
        Rise360ModuleInteraction.create!(
          verb: Rise360ModuleInteraction::ANSWERED,
          user: user,
          canvas_course_id: 333,
          canvas_assignment_id: canvas_assignment_id,
          activity_id: "#{activity_id}/somequizid/secondquestion",
          success: false,
          new: true,
        )
      end

      it "computes the correct grade" do
        grade = compute_service.run()
        expect(grade.total_score).to eq( 1.0*4.0 + 0.5*4.0 + 1.0*2.0 )
      end
    end

    context "with full mastery and partial engagenemt" do
      # Two total questions.
      let(:rise360_module_version) { create(:rise360_module_version, quiz_questions: 2) }

      before :each do
        # 50% progress.
        Rise360ModuleInteraction.create!(
          verb: Rise360ModuleInteraction::PROGRESSED,
          user: user,
          canvas_course_id: course.canvas_course_id,
          canvas_assignment_id: canvas_assignment_id,
          activity_id: activity_id,
          progress: 50,
          new: true,
        )

        # Both correct.
        Rise360ModuleInteraction.create!(
          verb: Rise360ModuleInteraction::ANSWERED,
          user: user,
          canvas_course_id: 333,
          canvas_assignment_id: canvas_assignment_id,
          activity_id: "#{activity_id}/somequizid/firstquestion",
          success: true,
          new: true,
        )
        Rise360ModuleInteraction.create!(
          verb: Rise360ModuleInteraction::ANSWERED,
          user: user,
          canvas_course_id: 333,
          canvas_assignment_id: canvas_assignment_id,
          activity_id: "#{activity_id}/somequizid/secondquestion",
          success: true,
          new: true,
        )
      end

      it "computes the correct grade" do
        grade = compute_service.run()
        expect(grade.total_score).to eq( 0.5*4.0 + 1.0*4.0 + 0.0*2.0 )
      end
    end

    context "module engagement grade" do
      # Generate random progress for interactions (not 100% though b/c we use 0 for completed on-time grade below)
      let(:progress) { [rand(0..99), rand(0..99), rand(0..99)] }
      let(:maximum) { progress.max }

      before(:each) do
        progress.each do |value|
          Rise360ModuleInteraction.create!(
            verb: Rise360ModuleInteraction::PROGRESSED,
            user: user,
            canvas_course_id: 333,
            canvas_assignment_id: canvas_assignment_id,
            activity_id: activity_id,
            progress: value,
            new: value != maximum, # Maximum value has new: false
          )
        end
      end

      it "returns maximum progress" do
        computed_engagement_grade = compute_service.run().engagement_grade
        expect(computed_engagement_grade).to eq(maximum)
      end
    end

    context "mastery quiz" do
      # Three total questions. Use denominator that generates remainder to test division
      let(:quiz_questions) { 3 }
      let(:rise360_module_version) { create(:rise360_module_version, quiz_questions: quiz_questions) }

      it "returns percent of correct answers" do

        expected_quiz_grade = (0.0/quiz_questions * 100)
        computed_quiz_grade = compute_service.run().quiz_grade
        expect(computed_quiz_grade).to eq(expected_quiz_grade)

        Rise360ModuleInteraction.create!(
          verb: Rise360ModuleInteraction::ANSWERED,
          user: user,
          canvas_course_id: 333,
          canvas_assignment_id: canvas_assignment_id,
          activity_id: "#{activity_id}/somequizid/firstquestion",
          success: true,
          new: true,
        )
        expected_quiz_grade = (1.0/quiz_questions * 100)
        computed_quiz_grade = compute_service.run().quiz_grade
        expect(computed_quiz_grade).to eq(expected_quiz_grade)

        Rise360ModuleInteraction.create!(
          verb: Rise360ModuleInteraction::ANSWERED,
          user: user,
          canvas_course_id: 333,
          canvas_assignment_id: canvas_assignment_id,
          activity_id: "#{activity_id}/somequizid/secondquestion",
          success: true,
          new: true,
        )
        expected_quiz_grade = (2.0/quiz_questions * 100)
        computed_quiz_grade = compute_service.run().quiz_grade
        expect(computed_quiz_grade).to eq(expected_quiz_grade)
      end

      it "uses success from most recent interaction" do
        quiz_question_id = "#{activity_id}/somequizid/somequestionid"
        timestamp = Time.now.utc.to_i

        # Initially a correct answer
        Rise360ModuleInteraction.create!(
          verb: Rise360ModuleInteraction::ANSWERED,
          user: user,
          canvas_course_id: 333,
          canvas_assignment_id: canvas_assignment_id,
          activity_id: "#{quiz_question_id}_#{timestamp}",
          success: true,
          new: true,
        )

        # Wrong answer later
        Rise360ModuleInteraction.create!(
          verb: Rise360ModuleInteraction::ANSWERED,
          user: user,
          canvas_course_id: 333,
          canvas_assignment_id: canvas_assignment_id,
          activity_id: "#{quiz_question_id}_#{timestamp + 1}",
          success: false, # User later go the same question wrong
          new: true,
        )

        expected_quiz_grade = (0.0/quiz_questions * 100)
        computed_quiz_grade = compute_service.run().quiz_grade
        expect(computed_quiz_grade).to eq(expected_quiz_grade)
      end
    end

    context "on-time grade" do
      subject { compute_service.run().on_time_score }

      let(:interactions) { Rise360ModuleInteraction.all }
      let(:due_date_obj) { 1.day.from_now.utc }
      let(:due_date) { due_date_obj.to_time.iso8601 }

      shared_examples 'incomplete module' do
        it { is_expected.to eq(0.0) }
      end

      shared_examples 'completed module' do
        it { is_expected.to eq(2.0) }
      end

      context "with no interactions" do
        it_behaves_like "incomplete module"
      end

      context "with only interactions after due date" do
        before :each do
          # All interactions after the due date.
          Rise360ModuleInteraction.create!(
            verb: Rise360ModuleInteraction::PROGRESSED,
            user: user,
            canvas_course_id: course.canvas_course_id,
            canvas_assignment_id: canvas_assignment_id,
            activity_id: activity_id,
            progress: 50,
            new: true,
            created_at: due_date_obj + 3.days
          )
          Rise360ModuleInteraction.create!(
            verb: Rise360ModuleInteraction::PROGRESSED,
            user: user,
            canvas_course_id: course.canvas_course_id,
            canvas_assignment_id: canvas_assignment_id,
            activity_id: activity_id,
            progress: 100,
            new: true,
            created_at: due_date_obj + 4.days
          )
        end

        it_behaves_like "incomplete module"
      end

      context "with some interactions before, completed interaction after due date" do
        before :each do
          # Completed interaction after the due date.
          # All other interactions before the due date.
          Rise360ModuleInteraction.create!(
            verb: Rise360ModuleInteraction::PROGRESSED,
            user: user,
            canvas_course_id: course.canvas_course_id,
            canvas_assignment_id: canvas_assignment_id,
            activity_id: activity_id,
            progress: 50,
            new: true,
            created_at: due_date_obj - 3.days,
          )
          Rise360ModuleInteraction.create!(
            verb: Rise360ModuleInteraction::PROGRESSED,
            user: user,
            canvas_course_id: course.canvas_course_id,
            canvas_assignment_id: canvas_assignment_id,
            activity_id: activity_id,
            progress: 100,
            new: true,
            created_at: due_date_obj + 3.days,
          )
        end

        it_behaves_like "incomplete module"
      end

      context "with completed interaction before due date" do
        before :each do
          # All interactions before the due date.
          Rise360ModuleInteraction.create!(
            verb: Rise360ModuleInteraction::PROGRESSED,
            user: user,
            canvas_course_id: course.canvas_course_id,
            canvas_assignment_id: canvas_assignment_id,
            activity_id: activity_id,
            progress: 50,
            new: true,
            created_at: due_date_obj - 4.days
          )
          Rise360ModuleInteraction.create!(
            verb: Rise360ModuleInteraction::PROGRESSED,
            user: user,
            canvas_course_id: course.canvas_course_id,
            canvas_assignment_id: canvas_assignment_id,
            activity_id: activity_id,
            progress: 100,
            new: true,
            created_at: due_date_obj - 3.days
          )
          # Create progress less than 100 created_at after the 100 progress. This can
          # happen when jumping back and forth after doing the module. Need to make
          # sure we always use the 100 progress to calculate on-time grade
          Rise360ModuleInteraction.create!(
            verb: Rise360ModuleInteraction::PROGRESSED,
            user: user,
            canvas_course_id: course.canvas_course_id,
            canvas_assignment_id: canvas_assignment_id,
            activity_id: activity_id,
            progress: 99,
            new: true,
            created_at: due_date_obj - 2.days
          )
        end

        it_behaves_like "completed module"
      end
    end  # on-time grade

  end  # run

end

# I just do a very basic test of the points display in the controller but here we
# loop over a bunch of values from 0 to 100 and make sure the math all works out.
# https://app.asana.com/0/1174274412967132/1201022023697611
# Note that I tried nesting this RSpec.describe inside the ComputeRise360ModuleGrade one
# but it needs to be at the top level
RSpec.describe ComputeRise360ModuleGrade::ComputedGradeBreakdown do

  describe '#total_score' do

    # Loop over all permutations of engagement scores and on time scores with a representative
    # sample of mastery quiz scores to make sure the math in the computed breakdown matches the total
    # that is sent to Canvas and displayed. Note: this is currently 15K permutations and I did catch
    # a bug by running it, woo!
    it 'computes the correct total_score' do

     # 11 is arbitrary. I just wanted to cover a reasonable set of numbers that could result in bad floating point math.
      mastery_grades = []
      [*1..11].each do |total_questions|
        [*0..total_questions].each do |correct_answers|
          mastery_grades << 100 * (correct_answers.to_f / total_questions.to_f)
        end
      end

      [*0..100].each do |engagement_grade|
        mastery_grades.each do |mastery_grade|
          [0, 100].each do |on_time_grade|
            gb = ComputeRise360ModuleGrade::ComputedGradeBreakdown.new(engagement_grade, mastery_grade, on_time_grade)
            expect(gb.total_score).to eq((gb.engagement_score + gb.quiz_score + gb.on_time_score).round(1))
          end
        end
      end
    end
  end

  describe "POINTS_POSSIBLE" do
    it "sums up to Rise360Module::POINTS_POSSIBLE" do
      total = 0.0
      ComputeRise360ModuleGrade::ComputedGradeBreakdown::POINTS_POSSIBLE.each do |key, score|
        total += score
      end
      expect(total.round(1)).to eq(Rise360Module::POINTS_POSSIBLE)
    end
  end


end
