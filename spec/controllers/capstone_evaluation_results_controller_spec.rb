require 'rails_helper'
require 'canvas_api'

RSpec.describe CapstoneEvaluationResultsController, type: :controller do
  render_views

  let(:canvas_client) { double(CanvasAPI) }
  let(:course) { create :course }
  let(:user) { create :registered_user }
  let(:section) { create :section, course: course }
  let(:cap_eval_results) { CapstoneEvaluationResultsController.new }
  let!(:lti_launch) {
    create(
      :lti_launch_assignment,
      canvas_course_id: course.canvas_course_id,
      canvas_user_id: user.canvas_user_id,
    )
  }

  before(:each) do
    sign_in user
  end

  describe 'GET #launch' do
    subject { get :launch, params: { lti_launch_id: lti_launch.id }}

    context 'with admin user' do
      before(:each) do
        user.add_role :admin
      end

      context 'with new capstone evaluation submissions to be graded' do
        let!(:ungraded_capstone_evaluation_submission) { create(:ungraded_capstone_evaluation_submission, course_id: course.id) }

        it 'shows there are new submissions to be published' do
          subject
          expect(response.body).to include('Number of new submissions ready to be published:')
        end
      end

      context 'with no new capstone evaluation submissions to be graded' do
        it 'shows there are no new submissions to be published' do
          subject
          expect(response.body).to include('There are no new submissions')
        end
      end
    end

    context 'with student enrollment' do
      before(:each) do
        user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      end

      context 'when submissions have not yet been graded' do
        it 'shows page telling them grade has not been calculated' do
          subject
          expect(response.body).to include('grade has not yet been calculated')
        end
      end

      context 'when submissions have been graded' do
        let!(:graded_capstone_evaluation_submission) { create(:graded_capstone_evaluation_submission, course_id: course.id) }
        let!(:ungraded_capstone_evaluation_submission) { create(:ungraded_capstone_evaluation_submission, course_id: course.id) }

        context 'if a user has a score for their Teamwork grade' do
          4.times do |i|
            # Create the 4 Capstone Evaluation Questions
            let!(:"cap_eval_quesion-#{i + 1}") { create(:capstone_evaluation_question, id: i + 1)}
            # Create 4 graded Capstone Evaluation Submission Answers (1 for each question) for the current user
            let!(:"graded_cap_eval_sub_answer-#{i + 1}"){ create(
              :capstone_evaluation_submission_answer,
              capstone_evaluation_submission_id: graded_capstone_evaluation_submission.id,
              for_user_id: user.id,
              capstone_evaluation_question_id: i + 1,
              input_value: 8
            ) }
            # Create 4 ungraded Capstone Evaluation Submission Answers for the current user
            let!(:"ungraded_cap_eval_sub_answer-#{i + 1}"){ create(
              :capstone_evaluation_submission_answer,
              capstone_evaluation_submission_id: ungraded_capstone_evaluation_submission.id,
              for_user_id: user.id,
              capstone_evaluation_question_id: i + 1,
              input_value: 10
            ) }
          end        

          it 'shows the page with the user\'s score' do
            subject
            expect(response.body).to include('Your Capstone Evaluation Teamwork total score is')
          end

          # only includes submission answers from graded answers - all scores of 8.0 * 4 = 32.0
          it 'only includes graded submission answers in the user\'s total score' do
            subject
            expect(response.body).to include('Your Capstone Evaluation Teamwork total score is: 32.0')
          end
        end

        # This can happen if there haven't been any submissions for a user, even though grades have been published
        context 'when a user doesn\'t have a score for their teamwork grade' do
          4.times do |i|
            # Create the 4 Capstone Evaluation Questions
            let!(:"cap_eval_quesion-#{i + 1}") { create(:capstone_evaluation_question, id: i + 1)}
            # Create 4 graded Capstone Evaluation Submission Answers for a different user
            let!(:"graded_cap_eval_sub_answer-#{i + 1}"){ create(
              :capstone_evaluation_submission_answer,
              capstone_evaluation_submission_id: graded_capstone_evaluation_submission.id,
              for_user_id: user.id + 1,
              capstone_evaluation_question_id: i + 1,
              input_value: 8
            ) }
          end

          it 'shows page telling them grade has not been calculated' do
            subject
            expect(response.body).to include('grade has not yet been calculated')
          end
        end
      end
    end

    context 'with TA enrollment' do
      it 'raises an error' do
        user.add_role RoleConstants::TA_ENROLLMENT, section
        expect { subject }.to raise_error Pundit::NotAuthorizedError
      end
    end
  end

  describe 'POST #score' do
    subject { post :score, params: { lti_launch_id: lti_launch.id } }
    let(:grade_capstone_evaluations_service) { double(GradeCapstoneEvaluations, run: nil) }

    context 'with admin user' do
      before(:each) do
        user.add_role :admin
        allow(CanvasAPI).to receive(:client).and_return(canvas_client)
        allow(canvas_client)
          .to receive(:update_grades)
          .and_return(nil)
        allow(GradeCapstoneEvaluations).to receive(:new).and_return(grade_capstone_evaluations_service)
        allow(grade_capstone_evaluations_service).to receive(:run)
      end

      context 'with no new capstone evaluation submissions' do
        it 'redirects to the capstone evaluation results page and flashes \'No new submissions\' alert' do
            subject
            expect(response).to redirect_to(launch_capstone_evaluation_results_path(lti_launch_id: lti_launch.id))
            expect(flash[:alert]).to match(/No new submissions to grade./)
        end

        it 'does not call the grade_capstone_evaluations service' do
          expect(grade_capstone_evaluations_service).not_to receive(:run)
          subject
        end
      end

      context 'with new capstone evaluation submissions to grade' do
        let!(:ungraded_capstone_evaluation_submission) { create(:ungraded_capstone_evaluation_submission, course_id: course.id) }

        it 'calls the grade_capstone_evaluations service' do
          expect(grade_capstone_evaluations_service).to receive(:run)
          subject
        end

        it 'redirects to the capstone evaluation results page and flashes success notice' do
            subject
            expect(response).to redirect_to(launch_capstone_evaluation_results_path(lti_launch_id: lti_launch.id))
            expect(flash[:notice]).to match(/Grades have been successfully published./)
        end
      end
    end

    context 'with fellow user' do
      it 'raises an error' do
        user.add_role RoleConstants::STUDENT_ENROLLMENT, section
        expect { subject }.to raise_error Pundit::NotAuthorizedError
      end
    end

    context 'with TA user' do
      it 'raises an error' do
        user.add_role RoleConstants::TA_ENROLLMENT, section
        expect { subject }.to raise_error Pundit::NotAuthorizedError
      end
    end
  end
end