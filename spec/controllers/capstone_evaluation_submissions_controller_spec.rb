require 'rails_helper'

RSpec.describe CapstoneEvaluationSubmissionsController, type: :controller do
  render_views

  let(:course) { create :course }
  let(:section) { create :section, course: course }
  let(:sf_client) { double(SalesforceAPI, get_accelerator_course_id_from_lc_playbook_course_id: nil) }

  before(:each) do
    sign_in user
    @lti_launch = create(
      :lti_launch_assignment,
      canvas_user_id: user.canvas_user_id,
    )
    allow(SalesforceAPI).to receive(:client).and_return(sf_client)
  end

  describe 'GET #show' do
    let(:user) { create :fellow_user, section: section }

    # This creates the submission for the current_user for that capstone_evaluation
    # The capstone_evaluation_submission has to be created here so it doesn't interfere with
    # the POST #create CapstoneEvaluationSubmission counts
    let(:capstone_evaluation_submission) { create(
      :capstone_evaluation_submission,
      user: user,
      course: course,
    ) }

    it 'returns a success response' do
      get(
        :show,
        params: {
          course_id: course.id,
          id: capstone_evaluation_submission.id,
          lti_launch_id: @lti_launch.id,
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
          lti_launch_id: @lti_launch.id,
        },
      )
    }

    shared_examples 'valid request' do
      scenario 'returns a success response' do
        subject
        expect(response).to be_successful
      end
    end

    shared_examples 'no one to review' do
      scenario 'displays a message' do
        subject
        expect(response.body).to include("You have no one to review.")
      end

      scenario 'does not have a form' do
        expect(response.body).not_to include("</form>")
      end
    end

    context 'as non-enrolled(admin) user' do
      let!(:user) { create :admin_user }
      let!(:fellow_user) { create :fellow_user, section: section }

      it_behaves_like 'valid request'
      it_behaves_like 'no one to review'
    end

    context 'as non-fellow (TA) user' do
      let!(:user) { create :ta_user, section: section }
      let!(:fellow_user) { create :fellow_user, section: section }

      it_behaves_like 'valid request'
      it_behaves_like 'no one to review'
    end

    context 'as the only Fellow user in section' do
      let!(:user) { create :fellow_user, section: section }

      it_behaves_like 'valid request'
      it_behaves_like 'no one to review'
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
        CapstoneEvaluationSubmission.create!(
          user: user,
          course: course,
        )
        subject
        expect(response).to redirect_to capstone_evaluation_submission_path(
          CapstoneEvaluationSubmission.last,
          lti_launch_id: @lti_launch.id,
        )
      end
    end

    context 'as an LC in an LC Playbook course with Fellows in section' do
      let!(:student_course) { create :course }
      let!(:student_section) { create :section, course: student_course }
      let(:sf_client) { double(SalesforceAPI, get_accelerator_course_id_from_lc_playbook_course_id: student_course.canvas_course_id) }
      let!(:user) { create :ta_user, section: student_section }
      let!(:eval_user) { create :fellow_user, section: student_section }

      before :each do
        # Enroll the LC in the LC Playbook course as a Student.
        user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      end

      it_behaves_like 'valid request'

      it 'shows form with Fellow' do
        subject
        expect(response.body).to include("</form>")
        expect(response.body).to include(eval_user.full_name)
        expect(response.body).not_to include (user.full_name)
      end

      it 'redirects to #show if there is a previous submission' do
        CapstoneEvaluationSubmission.create!(
          user: user,
          course: course,
        )
        subject
        expect(response).to redirect_to capstone_evaluation_submission_path(
          CapstoneEvaluationSubmission.last,
          lti_launch_id: @lti_launch.id,
        )
      end
    end
  end

  describe 'POST #create' do
    let(:lti_advantage_api) { double(LtiAdvantageAPI) }
    let(:user) { create(:fellow_user, section: section) }
    let(:peer_user) { create(:peer_user, section: section) }
    let(:question) { create(:capstone_evaluation_question) }

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
          capstone_evaluation: {
            peer_user.id.to_s => {
              question.id.to_s => 'My answer value',
            },
          },
          lti_launch_id: @lti_launch.id,
        }
      )
    }

    it 'redirects to #show' do
      expect(subject).to redirect_to capstone_evaluation_submission_path(CapstoneEvaluationSubmission.last, lti_launch_id: @lti_launch.id)
    end

    it 'creates a capstone_evaluation submission' do
      expect { subject }.to change(CapstoneEvaluationSubmission, :count).by(1)
    end

    it 'saves the submitted answer' do
      expect { subject }.to change(CapstoneEvaluationSubmissionAnswer, :count).by(1)
    end

    it 'updates the Canvas assignment' do
      subject
      expect(lti_advantage_api)
        .to have_received(:create_score)
        .once
    end
  end
end
