# frozen_string_literal: true

require 'rails_helper'
require 'canvas_api'

RSpec.describe GradeCapstoneEvaluations do
  let(:canvas_client) { double(CanvasAPI) }
  let(:course) { create(:course) }
  let(:section) { create(:section_with_canvas_id, course: course) }
  let(:user) { create :admin_user }
  let(:fellow_with_already_graded_submission) { create(:fellow_user, section: section) }
  let(:fellow_with_new_submission) { create(:fellow_user, section: section) }
  let!(:fellow_with_no_submission) { create(:fellow_user, section: section) }
  let(:lti_launch) {create(:lti_launch_assignment,
      canvas_course_id: course.canvas_course_id,
      canvas_user_id: user.canvas_user_id,
    )
  }
  let!(:ungraded_capstone_evaluation_submission) { create(:ungraded_capstone_evaluation_submission,
    course_id: course.id,
    user_id: fellow_with_new_submission.id
    ) }
  let(:new_capstone_eval_submissions) { CapstoneEvaluationSubmission.where(new: true) }
  let(:all_capstone_eval_submissions) { CapstoneEvaluationSubmission.all }
  let(:grade_capstone_evaluations_service) {
    GradeCapstoneEvaluations.new(
      course,
      lti_launch
     )
  }

  describe '#run' do
    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(canvas_client)
        .to receive(:update_grades)
        .and_return(nil)
    end

    subject(:run_service) { grade_capstone_evaluations_service.run() }

    it 'calls update_grades' do
      expect(canvas_client).to receive(:update_grades)
      subject
    end

    it 'updates ungraded assignments that were graded to new: false' do
       expect(ungraded_capstone_evaluation_submission.new).to eq(true)
       subject
       expect(ungraded_capstone_evaluation_submission.reload.new).to eq(false)
     end
  end

  describe '#grade_capstone_eval_questions' do
    let!(:graded_capstone_evaluation_submission) { create(:graded_capstone_evaluation_submission,
      course_id: course.id,
      user_id: fellow_with_already_graded_submission.id
    ) }
    let!(:graded_capstone_evaluation_submission_1) { create(:graded_capstone_evaluation_submission, course_id: course.id) }

    4.times do |i|
      # Create the 4 Capstone Evaluation Questions
      let!(:"cap_eval_quesion-#{i + 1}") { create(:capstone_evaluation_question, id: i + 1)}
      # Create 4 graded Capstone Evaluation Submission Answers for the current user
      let!(:"graded_cap_eval_sub_answer-#{i + 1}"){ create(
        :capstone_evaluation_submission_answer,
        capstone_evaluation_submission_id: graded_capstone_evaluation_submission.id,
        for_user_id: fellow_with_already_graded_submission.id,
        capstone_evaluation_question_id: i + 1,
        input_value: 8
      ) }
      # Create 4 more graded Capstone Evaluation Submission Answers for the current user
      # with a different score to check that it averages correctly
      let!(:"more_graded_cap_eval_sub_answers-#{i + 4}"){ create(
        :capstone_evaluation_submission_answer,
        capstone_evaluation_submission_id: graded_capstone_evaluation_submission_1.id,
        for_user_id: fellow_with_already_graded_submission.id,
        capstone_evaluation_question_id: i + 1,
        input_value: 10
      ) }
      # Create ungraded submission answers for the current user
      let!(:"ungraded_cap_eval_sub_answers-#{i + 8}"){ create(
        :capstone_evaluation_submission_answer,
        capstone_evaluation_submission_id: ungraded_capstone_evaluation_submission.id,
        for_user_id: fellow_with_already_graded_submission.id,
        capstone_evaluation_question_id: i + 1,
        input_value: 6
      ) }
    end

    context 'when using #grade_capstone_eval_questions to grade all submissions and true is passed in for all_submissions' do
      subject { grade_capstone_evaluations_service.grade_capstone_eval_questions(fellow_with_already_graded_submission, true) }

      it 'returns hash with average score for each question for the current user using all submissions' do
        expect(subject.values).to eq([8.0, 8.0, 8.0, 8.0])
      end
    end

    context 'when using #grade_capstone_eval_questions to show a fellow their grade and false is passed in for all_submissions' do
      subject { grade_capstone_evaluations_service.grade_capstone_eval_questions(fellow_with_already_graded_submission, false) }

      it 'returns a hash with average score for each question for the current user using graded submissions' do
        expect(subject.values).to eq([9.0, 9.0, 9.0, 9.0])
      end
    end

  end

  describe '#submissions_have_been_graded?' do
    subject { grade_capstone_evaluations_service.submissions_have_been_graded? }

    context 'with no graded submissions' do
      it 'returns false if there are no graded submissions' do
        expect(subject).to eq(false)
      end
    end

    context 'with graded submissions' do
      let!(:graded_submission) { create(:graded_capstone_evaluation_submission, course_id: course.id) }

      it 'returns true if there are graded submissions' do
        expect(subject).to eq(true)
      end
    end
  end

  describe '#fellow_total_score' do
    let!(:graded_capstone_evaluation_submission) { create(:graded_capstone_evaluation_submission,
      course_id: course.id,
      user_id: fellow_with_already_graded_submission.id
    ) }
    let!(:graded_capstone_evaluation_submission_1) { create(:graded_capstone_evaluation_submission, course_id: course.id) }

    4.times do |i|
      # Create the 4 Capstone Evaluation Questions
      let!(:"cap_eval_quesion-#{i + 1}") { create(:capstone_evaluation_question, id: i + 1)}
      # Create 4 graded Capstone Evaluation Submission Answers for the current user
      let!(:"graded_cap_eval_sub_answer-#{i + 1}"){ create(
        :capstone_evaluation_submission_answer,
        capstone_evaluation_submission_id: graded_capstone_evaluation_submission.id,
        for_user_id: fellow_with_already_graded_submission.id,
        capstone_evaluation_question_id: i + 1,
        input_value: 8
      ) }
      # Create 4 more graded Capstone Evaluation Submission Answers for the current user
      # with a different score to check that it averages correctly
      let!(:"more_graded_cap_eval_sub_answers-#{i + 4}"){ create(
        :capstone_evaluation_submission_answer,
        capstone_evaluation_submission_id: graded_capstone_evaluation_submission_1.id,
        for_user_id: fellow_with_already_graded_submission.id,
        capstone_evaluation_question_id: i + 1,
        input_value: 10
      ) }
      # Create ungraded submission answers for the current user
      let!(:"ungraded_cap_eval_sub_answers-#{i + 8}"){ create(
        :capstone_evaluation_submission_answer,
        capstone_evaluation_submission_id: ungraded_capstone_evaluation_submission.id,
        for_user_id: fellow_with_already_graded_submission.id,
        capstone_evaluation_question_id: i + 1,
        input_value: 6
      ) }
    end

    context 'for a user with graded submissions' do
      subject { grade_capstone_evaluations_service.fellow_total_score(fellow_with_already_graded_submission) }

      it 'returns the Capstone Evaluation Teamwork total score for the given user' do
        expect(subject).to eq(36)
      end
    end

    context 'for a user with no graded submissions' do
      subject { grade_capstone_evaluations_service.fellow_total_score(fellow_with_new_submission) }

      it 'returns the Capstone Evaluation Teamwork total score for the given user' do
        expect(subject.nan?).to eq(true)
      end
    end
  end

  describe '#user_has_grade?' do
    context 'with graded submissions' do
      let!(:graded_capstone_evaluation_submission) { create(:graded_capstone_evaluation_submission,
        course_id: course.id,
        user_id: fellow_with_already_graded_submission.id
      ) }

      4.times do |i|
        # Create the 4 Capstone Evaluation Questions
        let!(:"cap_eval_quesion-#{i + 1}") { create(:capstone_evaluation_question, id: i + 1)}
        # Create 4 graded Capstone Evaluation Submission Answers for the current user
        let!(:"graded_cap_eval_sub_answer-#{i + 1}"){ create(
          :capstone_evaluation_submission_answer,
          capstone_evaluation_submission_id: graded_capstone_evaluation_submission.id,
          for_user_id: fellow_with_already_graded_submission.id,
          capstone_evaluation_question_id: i + 1,
          input_value: 8
        ) }
      end

      context 'with a user that has a Capstone Evaluation Teamwork grade' do
        subject { grade_capstone_evaluations_service.user_has_grade?(fellow_with_already_graded_submission) }

        it 'returns true' do
          expect(subject).to eq(true)
        end
      end

      context 'with a user that does not have a Capstone Evaluation Teamwork grade' do
        subject { grade_capstone_evaluations_service.user_has_grade?(fellow_with_new_submission) }

        it 'returns false' do
          expect(subject).to eq(false)
        end
      end
    end

    context 'with no graded submissions' do
      subject { grade_capstone_evaluations_service.user_has_grade?(fellow_with_new_submission) }

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end

  describe '#students_with_published_submissions' do
    let!(:graded_capstone_evaluation_submission) { create(:graded_capstone_evaluation_submission,
      course_id: course.id,
      user_id: fellow_with_already_graded_submission.id
    ) }

    subject { grade_capstone_evaluations_service.students_with_published_submissions() }

    it 'returns an array of users with already graded submissions' do
      expect(subject).to eq([fellow_with_already_graded_submission])
    end
  end

  describe '#remaining_students' do
    let!(:graded_capstone_evaluation_submission) { create(:graded_capstone_evaluation_submission,
      course_id: course.id,
      user_id: fellow_with_already_graded_submission.id
    ) }

    subject { grade_capstone_evaluations_service.remaining_students() }

    it 'returns an array of users who have not yet submitted a Capstone Evaluation' do
      expect(subject).to eq([fellow_with_no_submission])
    end
  end

  describe '#students_with_new_submissions' do
    subject { grade_capstone_evaluations_service.students_with_new_submissions() }

    it 'returns an array of users with new ungraded submissions' do
      expect(subject).to eq([fellow_with_new_submission])
    end
  end
end