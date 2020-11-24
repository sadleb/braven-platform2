require 'rails_helper'

RSpec.describe PeerReviewSubmissionsController, type: :controller do
  render_views

  let(:course) { create :course }
  let(:section) { create :section, course: course }
  let(:user) { create :fellow_user, section: section }

  let(:lti_launch) {
    create(
      :lti_launch_assignment,
      canvas_user_id: user.canvas_user_id,
    )
  }

  describe 'GET #show' do
    # This creates the submission for the Fellow for that peer_review
    # The peer_review_submission has to be created here so it doesn't interfere with
    # the POST #create PeerReviewSubmission counts
    let(:peer_review_submission) { create(
      :peer_review_submission,
      user: user,
      course: course,
    )}

    it 'returns a success response' do
      get(
        :show,
        params: {
          course_id: course.id,
          id: peer_review_submission.id,
          type: 'Course',
          state: lti_launch.state,
        },
      )
      expect(response).to be_successful
    end
  end

  describe 'GET #new' do
    it 'returns a success response' do
      get(
        :new,
        params: {
          course_id: course.id,
          type: 'Course',
          state: lti_launch.state,
        },
      )
      expect(response).to be_successful
    end

    it 'redirects to #show if there is a previous submission' do
      PeerReviewSubmission.create!(
        user: user,
        course: course,
      )
      get(
        :new,
        params: {
          course_id: course.id,
          type: 'Course',
          state: lti_launch.state,
        },
      )
      expect(response).to redirect_to peer_review_submission_path(PeerReviewSubmission.last, state: lti_launch.state)
    end
  end

  describe 'POST #create' do
    let(:lti_advantage_api) { double(LtiAdvantageAPI) }
    let(:peer_user) { create(:peer_user, section: section) }
    let(:question) { create(:peer_review_question) }

    before(:each) do
      allow(LtiAdvantageAPI).to receive(:new).and_return(lti_advantage_api)
      allow(lti_advantage_api).to receive(:create_score)
      allow(LtiScore).to receive(:new_full_credit_submission)
    end

    subject {
      post(
        :create,
        params: {
          course_id: course.id,
          type: 'Course',
          peer_review: {
            peer_user.id.to_s => {
              question.id.to_s => 'My answer value',
            },
          },
          state: lti_launch.state,
        }
      )
    }

    it 'redirects to #show' do
      expect(subject).to redirect_to peer_review_submission_path(PeerReviewSubmission.last, state: lti_launch.state)
    end

    it 'creates a peer_review submission' do
      expect { subject }.to change(PeerReviewSubmission, :count).by(1)
    end

    it 'saves the submitted answer' do
      expect { subject }.to change(PeerReviewSubmissionAnswer, :count).by(1)
    end

    it 'updates the Canvas assignment' do
      subject
      expect(lti_advantage_api)
        .to have_received(:create_score)
        .once
    end
  end
end
