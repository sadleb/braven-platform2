require 'rails_helper'

RSpec.describe PeerReviewSubmissionsController, type: :controller do
  render_views

  let(:course) { create :course }
  let(:section) { create :section, course: course }

  before(:each) do
    @lti_launch = create(
      :lti_launch_assignment,
      canvas_user_id: user.canvas_user_id,
    )
  end

  describe 'GET #show' do
    let(:user) { create :fellow_user, section: section }

    # This creates the submission for the Fellow for that peer_review
    # The peer_review_submission has to be created here so it doesn't interfere with
    # the POST #create PeerReviewSubmission counts
    let(:peer_review_submission) { create(
      :peer_review_submission,
      user: user,
      course: course,
    ) }

    it 'returns a success response' do
      get(
        :show,
        params: {
          course_id: course.id,
          id: peer_review_submission.id,
          state: @lti_launch.state,
        },
      )
      expect(response).to be_successful
    end
  end

  # Note: This set of specs uses let! for all user objects so they're created
  # **before** the GET request is made. This is because we need the users in
  # the DB when constructing the form.
  describe 'GET #new' do
    subject {
      get(
        :new,
        params: {
          course_id: course.id,
          state: @lti_launch.state,
        },
      )
    }

    shared_examples 'valid request' do
      scenario 'returns a success response' do
        subject
        expect(response).to be_successful
      end
    end

    shared_examples 'no peers to review' do
      scenario 'displays a message' do
        subject
        expect(response.body).to include("You have no peers to review.")
      end

      scenario 'does not have a form' do
        expect(response.body).not_to include("</form>")
      end
    end

    context 'as non-enrolled(admin) user' do
      let!(:user) { create :admin_user }
      let!(:fellow_user) { create :fellow_user, section: section }

      it_behaves_like 'valid request'
      it_behaves_like 'no peers to review'
    end

    context 'as non-fellow (TA) user' do
      let!(:user) { create :ta_user, section: section }
      let!(:fellow_user) { create :fellow_user, section: section }

      it_behaves_like 'valid request'
      it_behaves_like 'no peers to review'
    end

    context 'as the only Fellow user in section' do
      let!(:user) { create :fellow_user, section: section }

      it_behaves_like 'valid request'
      it_behaves_like 'no peers to review'
    end

    context 'as a Fellow with peers in section' do
      let!(:user) { create :fellow_user, section: section }
      let!(:peer_user) { create :peer_user, section: section }

      it_behaves_like 'valid request'

      it 'shows form with peer' do
        subject
        expect(response.body).to include("</form>")
        expect(response.body).to include(peer_user.full_name)
        expect(response.body).not_to include (user.full_name)
      end

      it 'redirects to #show if there is a previous submission' do
        PeerReviewSubmission.create!(
          user: user,
          course: course,
        )
        subject
        expect(response).to redirect_to peer_review_submission_path(
          PeerReviewSubmission.last,
          state: @lti_launch.state,
        )
      end
    end
  end

  describe 'POST #create' do
    let(:user) { create :fellow_user }
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
          peer_review: {
            peer_user.id.to_s => {
              question.id.to_s => 'My answer value',
            },
          },
          state: @lti_launch.state,
        }
      )
    }

    it 'redirects to #show' do
      expect(subject).to redirect_to peer_review_submission_path(PeerReviewSubmission.last, state: @lti_launch.state)
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
