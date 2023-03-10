# frozen_string_literal: true

require 'rails_helper'
require 'canvas_api'

RSpec.describe GradeCapstoneEvaluations do
  let(:canvas_client) { double(CanvasAPI) }
  let(:course) { create(:course) }
  let(:lc_course) { create(:course) }
  let(:other_course) { create(:course) }
  let(:cohort_section) { create(:cohort_section, course: course) }
  let(:lc_section) { create(:cohort_section, course: lc_course) }
  let(:user) { create :admin_user }
  let(:fellow_with_already_graded_submission) { create(:fellow_user, section: cohort_section) }
  let(:fellow_with_new_submission) { create(:fellow_user, section: cohort_section) }
  let(:lc_with_new_submission) { create(:lc_playbook_user, section: lc_section) }
  let(:lti_launch) {create(:lti_launch_assignment,
      canvas_course_id: course.canvas_course_id,
      canvas_user_id: user.canvas_user_id,
    )
  }
  let!(:ungraded_capstone_evaluation_submission) { create(:ungraded_capstone_evaluation_submission,
    course_id: course.id,
    user_id: fellow_with_new_submission.id
  ) }
  let!(:lc_ungraded_capstone_evaluation_submission) { create(:ungraded_capstone_evaluation_submission,
    course_id: lc_course.id,
    user_id: lc_with_new_submission.id
  ) }
  let(:new_capstone_eval_submissions) { CapstoneEvaluationSubmission.where(new: true) }
  let(:all_capstone_eval_submissions) { CapstoneEvaluationSubmission.all }
  let(:grade_capstone_evaluations_service) {
    GradeCapstoneEvaluations.new(
      course,
      lc_course,
      lti_launch
     )
  }

  describe '#run' do
    # Need to create ungraded submission answers for a user to check if create_lti_submission gets called
    4.times do |i|
      # Create the 4 Capstone Evaluation Questions
      let!(:"cap_eval_quesion-#{i + 1}") { create(:capstone_evaluation_question, id: i + 1)}
      # Create 4 ungraded Capstone Evaluation Submission Answers for a user
      let!(:"ungraded_cap_eval_sub_answer-#{i + 1}"){ create(
        :capstone_evaluation_submission_answer,
        capstone_evaluation_submission_id: ungraded_capstone_evaluation_submission.id,
        for_user_id: fellow_with_new_submission.id,
        capstone_evaluation_question_id: i + 1,
        input_value: 8
      ) }
    end

    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(canvas_client).to receive(:get_assignment_submissions).and_return({})
      allow(canvas_client).to receive(:create_lti_submission)
      allow(canvas_client).to receive(:update_grades)
    end

    subject(:run_service) { grade_capstone_evaluations_service.run() }

    context 'when grading a user for the first time' do
      context 'for active users in the course' do
        it 'calls create_lti_submission' do
          expect(canvas_client).to receive(:create_lti_submission).once
          subject
        end
      end

      context 'for dropped users' do
        # Create user in the course
        let!(:fellow_to_be_dropped) { create(:fellow_user, section: cohort_section) }
        # Create ungraded submission
        let!(:dropped_ungraded_cap_eval_submission) { create(:ungraded_capstone_evaluation_submission, course_id: course.id) }
        # Create ungraded submissions for the user who will be dropped
        4.times do |i|
          # Create 4 ungraded Capstone Evaluation Submission Answers for a user
          let!(:"dropped_ungraded_cap_eval_sub_answer-#{i + 1}"){ create(
            :capstone_evaluation_submission_answer,
            capstone_evaluation_submission_id: dropped_ungraded_cap_eval_submission.id,
            for_user_id: fellow_to_be_dropped.id,
            capstone_evaluation_question_id: i + 1,
            input_value: 8
          ) }
        end

        it 'doesn\'t call create_lti_submission' do
          # Drop user from the course by deleting their enrollments
          UserRole.where(user_id: fellow_to_be_dropped.id).delete_all
          # It should still call create_lti_submission for submission answers for fellow_with_new_submission
          # but not for the submission answers for fellow_to_be_dropped
          expect(canvas_client).to receive(:create_lti_submission).once
          subject
        end
      end
    end

    context 'when regrading a user' do
      before(:each) do
        allow(canvas_client)
          .to receive(:get_assignment_submissions)
          .and_return({fellow_with_new_submission.canvas_user_id => {"already_has_submission"=>true}})
      end

      it 'does not create a new Canvas LTI submission' do
        expect(canvas_client).not_to receive(:create_lti_submission)
        subject
      end
    end

    it 'calls update_grades' do
      expect(canvas_client).to receive(:update_grades)
      subject
    end

    it 'updates ungraded assignments that were graded to new: false' do
      expect(ungraded_capstone_evaluation_submission.new).to eq(true)
      subject
      expect(ungraded_capstone_evaluation_submission.reload.new).to eq(false)
    end

    context 'with a failing user' do
      # Create a second user with submissions to be graded
      let!(:new_fellow_user) { create(:fellow_user, section: cohort_section) }
      4.times do |i|
        let!(:"ungraded_sub_answer-for_invalid_fellow#{i + 1}"){ create(
          :capstone_evaluation_submission_answer,
          capstone_evaluation_submission_id: ungraded_capstone_evaluation_submission.id,
          for_user_id: new_fellow_user.id,
          capstone_evaluation_question_id: i + 1,
          input_value: 8
        ) }
      end

      before(:each) do
        allow(Honeycomb).to receive(:add_alert)
        allow(canvas_client).to receive(:create_lti_submission).and_raise
      end

      # Both users will fail, but we want to make sure it continues trying to create a grade for
      # the second user after the first one fails (and doesn't just fail for all after the first failure)
      it 'skips failing users and continues grading subsequent users' do
        expect(canvas_client).to receive(:create_lti_submission).twice
        subject
      end

      it 'sends Honeycomb alert' do
        subject
        expect(Honeycomb).to have_received(:add_alert).with('capstone_eval_grading_failed', anything).twice
      end
    end
  end

  describe '#grade_capstone_eval_questions' do
    let(:graded_capstone_evaluation_submission) { create(:graded_capstone_evaluation_submission,
      course_id: course.id,
      user_id: fellow_with_already_graded_submission.id
    ) }
    let(:graded_capstone_evaluation_submission_1) { create(:graded_capstone_evaluation_submission, course_id: course.id) }
    let(:ungraded_capstone_eval_submission_for_other_course) { create(:ungraded_capstone_evaluation_submission, course_id: other_course.id)}

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
      # Create ungraded submission answers from an LC for the current user
      let!(:"lc_ungraded_cap_eval_sub_answers-#{i + 12}"){ create(
        :capstone_evaluation_submission_answer,
        capstone_evaluation_submission_id: lc_ungraded_capstone_evaluation_submission.id,
        for_user_id: fellow_with_already_graded_submission.id,
        capstone_evaluation_question_id: i + 1,
        input_value: 4
      ) }
      # Create ungraded submission answers for the current user for another course they are enrolled in
      # This should not be incorporated into the grade since it's not for this course
      let!(:"ungraded_cap_eval_sub_answers-#{i + 16}"){ create(
        :capstone_evaluation_submission_answer,
        capstone_evaluation_submission_id: ungraded_capstone_eval_submission_for_other_course.id,
        for_user_id: fellow_with_already_graded_submission.id,
        capstone_evaluation_question_id: i + 1,
        input_value: 2
      ) }
    end

    context 'when using #grade_capstone_eval_questions to grade all submissions and true is passed in for all_submissions' do
      subject { grade_capstone_evaluations_service.grade_capstone_eval_questions(fellow_with_already_graded_submission, true) }

      it 'returns hash with average score for each question for the current user using all student and LC submissions' do
        expect(subject.values).to eq([7.0, 7.0, 7.0, 7.0])
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
    let!(:lc_graded_capstone_evaluation_submission) { create(:graded_capstone_evaluation_submission, course_id: lc_course.id) }
    let(:graded_capstone_eval_submission_for_other_course) { create(:graded_capstone_evaluation_submission, course_id: other_course.id)}

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
        capstone_evaluation_submission_id: lc_graded_capstone_evaluation_submission.id,
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
      # Create graded submission answers for the current user for another course they are enrolled in
      # This should not be incorporated into the grade since it's not for this course
      let!(:"graded_cap_eval_sub_answers-#{i + 12}"){ create(
        :capstone_evaluation_submission_answer,
        capstone_evaluation_submission_id: graded_capstone_eval_submission_for_other_course.id,
        for_user_id: fellow_with_already_graded_submission.id,
        capstone_evaluation_question_id: i + 1,
        input_value: 2
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

  describe '#users_with_published_submissions' do
    let(:lc_with_already_graded_submission) { create(:lc_playbook_user, section: lc_section) }
    let!(:graded_capstone_evaluation_submission) { create(:graded_capstone_evaluation_submission,
      course_id: course.id,
      user_id: fellow_with_already_graded_submission.id
    ) }
    let!(:lc_graded_capstone_evaluation_submission) { create(:graded_capstone_evaluation_submission,
      course_id: lc_course.id,
      user_id: lc_with_already_graded_submission.id
    ) }

    subject { grade_capstone_evaluations_service.users_with_published_submissions() }

    it 'returns an array of users (Fellows and LCs) with already graded submissions' do
      expect(subject).to eq([fellow_with_already_graded_submission, lc_with_already_graded_submission])
    end
  end

  describe '#remaining_users' do
    let!(:fellow_with_no_submission) { create(:fellow_user, section: cohort_section) }
    let!(:lc_with_no_submission) { create(:lc_user, accelerator_section: cohort_section) }

    subject { grade_capstone_evaluations_service.remaining_users() }

    it 'returns an array of users (Fellows and LCs) who have not yet submitted a Capstone Evaluation' do
      expect(subject).to eq([fellow_with_no_submission, lc_with_no_submission])
    end
  end

  describe '#users_with_new_submissions' do
    subject { grade_capstone_evaluations_service.users_with_new_submissions() }

    it 'returns an array of users (Fellows and LCs) with new ungraded submissions' do
      expect(subject).to eq([fellow_with_new_submission, lc_with_new_submission])
    end
  end
end
