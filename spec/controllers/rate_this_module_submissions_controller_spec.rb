require 'rails_helper'

RSpec.describe RateThisModuleSubmissionsController, type: :controller do
  render_views

  let(:course) { create :course }
  let(:section) { create :section, course: course }
  let(:user) { create :fellow_user, section: section }
  let(:course_rise360_module_version) { create :course_rise360_module_version, course: course }

  let(:lti_launch) {
    create(
      :lti_launch_assignment,
      canvas_course_id: course.canvas_course_id,
      canvas_user_id: user.canvas_user_id,
      canvas_assignment_id: course_rise360_module_version.canvas_assignment_id,
    )
  }

  before :each do
    sign_in user
  end

  # Note: adding headers in controller specs is discouraged, but we're doing it
  # anyway because this specific usecase is very simple and this way is more
  # consistent with the rest of our specs.
  # See https://relishapp.com/rspec/rspec-rails/v/4-0/docs/controller-specs.
  describe 'GET #launch' do
    subject { get(:launch) }

    before :each do
      # Set the LTI state from the referrer header.
      request.headers['Referer'] = "https://example.org/?auth=LtiState%20#{lti_launch.state}"
    end

    context 'with valid launch' do
      it 'creates a submission if one did not exist' do
        expect { subject }.to change(RateThisModuleSubmission, :count).by(1)
      end

      it 'uses the same submission on the second launch request' do
        subject
        expect { subject }.not_to change(RateThisModuleSubmission, :count)
      end

      it 'creates submission tied to current_user and canvas_assignment_id' do
        subject
        submission = RateThisModuleSubmission.last
        expect(submission.course_rise360_module_version).to eq(course_rise360_module_version)
        expect(submission.user).to eq(user)
      end

      it 'redirects to #edit' do
        expect(subject).to redirect_to edit_rate_this_module_submission_path(
          RateThisModuleSubmission.last,
          lti_launch_id: lti_launch.id,
        )
      end
    end
  end

  describe 'GET #edit' do
    let(:other_params) { {} }
    let(:rate_this_module_submission) { create(
      :rate_this_module_submission,
      course_rise360_module_version: course_rise360_module_version,
      user: user,
    ) }

    subject { get(:edit, params: {
        id: rate_this_module_submission.id,
        lti_launch_id: lti_launch.id,
      }.merge(other_params)
    ) }

    it "shows the form" do
      subject
      expect(response.body).to include("Rate This Module")
      expect(response.body).to include("Submit")
      expect(response.body).not_to include("Feedback submitted")
    end

    context 'when submitted' do
      let(:other_params) { {show_alert: true} }
      it 'shows the alert' do
        subject
        expect(response.body).to include("Feedback submitted")
      end
    end

    context 'when submitted' do
      let(:other_params) { {submitted: true} }
      it 'shows Re-Submit instead of Submit' do
        subject
        expect(response.body).to include("Re-Submit")
      end
    end
  end

  describe 'PUT #update' do
    let(:rate_this_module_submission) { create(
      :rate_this_module_submission,
      course_rise360_module_version: course_rise360_module_version,
      user: user,
    ) }

    subject {
      put(
        :update,
        params: {
          id: rate_this_module_submission.id,
          rate_this_module_submission: {
            'module_score': '9',
            'module_feedback': 'thanks i love it',
          },
          lti_launch_id: lti_launch.id,
        },
      )
    }

    context 'with valid params' do
      it 'uses existing submission' do
        rate_this_module_submission 
        expect { subject }.not_to change(RateThisModuleSubmission, :count)
      end

      it 'first submission creates 2 (# inputs in form) answers' do
        expect { subject }.to change(RateThisModuleSubmissionAnswer, :count).by(2)
        score_answer = rate_this_module_submission.answers.find_by(input_name: 'module_score')
        expect(score_answer.input_value).to eq('9')
        feedback_answer = rate_this_module_submission.answers.find_by(input_name: 'module_feedback')
        expect(feedback_answer.input_value).to eq('thanks i love it')
      end

      it 'subsequent submissions use existing submission answers' do
        subject
        expect { subject }.not_to change(RateThisModuleSubmissionAnswer, :count)
      end

      it 'redirects to #edit with success params' do
        subject
        expect(response).to redirect_to edit_rate_this_module_submission_path(
          rate_this_module_submission,
          lti_launch_id: lti_launch.id,
          show_alert: true,
          submitted: true,
        )
      end
    end
  end
end
