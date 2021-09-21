require 'rails_helper'

RSpec.describe FellowEvaluationSubmissionsController, type: :controller do
  render_views

  let(:lc_playbook_course) { create :course, canvas_course_id: 1 }
  let(:lc_playbook_section) { create :section, course: lc_playbook_course }

  let(:accelerator_course) { create :course, canvas_course_id: 2 }
  let(:accelerator_section) { create :section, course: accelerator_course }

  let(:salesforce_client) { double(SalesforceAPI) }

  before(:each) do
    sign_in user
    @lti_launch = create(
      :lti_launch_assignment,
      canvas_user_id: user.canvas_user_id,
    )
    allow(SalesforceAPI).to receive(:client).and_return(salesforce_client)
    allow(salesforce_client)
      .to receive(:get_accelerator_course_id_from_lc_playbook_course_id)
      .with(lc_playbook_course.canvas_course_id)
      .and_return(accelerator_course.canvas_course_id)
  end

  shared_examples 'valid request' do
    scenario 'returns a success response' do
      subject
      expect(response).to be_successful
    end
  end

  shared_examples 'not permitted' do
    scenario 'throws a pundit error' do
      expect { subject }.to raise_error Pundit::NotAuthorizedError
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
          course_id: lc_playbook_course.id,
          lti_launch_id: @lti_launch.id,
        },
      )
    }

    context 'as non-enrolled user' do
      let(:user) { create :registered_user }
      it_behaves_like 'not permitted'
    end

    shared_examples 'no fellows to review' do
      scenario 'displays a message' do
        subject
        expect(response.body).to include("You have no fellows to review.")
      end

      scenario 'does not have a form' do
        expect(response.body).not_to include("</form>")
      end
    end

    context 'as non-enrolled (admin) user' do
      let!(:user) { create :admin_user }
      let!(:fellow_user) { create :fellow_user, section: accelerator_section }

      it_behaves_like 'valid request'
      it_behaves_like 'no fellows to review'
    end

    context 'as a leadership coach' do
      let!(:user) { create :lc_playbook_user, section: lc_playbook_section }

      before(:each) do
        user.add_role RoleConstants::TA_ENROLLMENT, accelerator_section
      end

      it_behaves_like 'valid request'

      context 'without any Fellows to review' do
        it_behaves_like 'no fellows to review'
      end

      context 'with Fellows to review' do
        let!(:fellow_user) { create :fellow_user, section: accelerator_section }

        it 'shows form with fellow only' do
          subject
          expect(response.body).to include("</form>")
          expect(response.body).to include(fellow_user.full_name)
          expect(response.body).not_to include (user.full_name)
        end

        it 'redirects to #show if there is a previous submission' do
          FellowEvaluationSubmission.create!(
            user: user,
            course: lc_playbook_course,
          )
          subject
          expect(response).to redirect_to fellow_evaluation_submission_path(
            FellowEvaluationSubmission.last,
            lti_launch_id: @lti_launch.id,
          )
        end
      end
    end
  end

  describe 'POST #create' do
    let(:user) { create :lc_playbook_user, section: lc_playbook_section }
    let(:fellow_user) { create :fellow_user, section: accelerator_section }
    let(:lti_advantage_api) { double(LtiAdvantageAPI) }

    before(:each) do
      user.add_role RoleConstants::TA_ENROLLMENT, accelerator_section
      allow(LtiAdvantageAPI).to receive(:new).and_return(lti_advantage_api)
      allow(lti_advantage_api).to receive(:create_score)
      allow(LtiScore).to receive(:new_full_credit_submission)
    end

    subject {
      post(
        :create,
        params: {
          course_id: lc_playbook_course.id,
          fellow_evaluation: {
            fellow_user.id.to_s => {
              'how-ready-to-be-professional' => 'My answer value',
            },
          },
          lti_launch_id: @lti_launch.id,
        },
      )
    }

    context 'as LC submitting' do
      it 'creates a submission' do
        expect { subject }.to change(FellowEvaluationSubmission, :count).by(1)
      end

      it 'saves the submitted answer' do
        expect { subject }.to change(FellowEvaluationSubmissionAnswer, :count).by(1)
      end

      it 'updates the Canvas assignment' do
        subject
        expect(lti_advantage_api)
          .to have_received(:create_score)
          .once
      end

      it 'redirects to #show' do
        expect(subject).to redirect_to fellow_evaluation_submission_path(
          FellowEvaluationSubmission.last,
          lti_launch_id: @lti_launch.id,
        )
      end
    end

    context 'as non-student (admin)' do
      let(:user) { create :admin_user }
      it_behaves_like 'not permitted'
    end

    context 'as non-student (TA)' do
      # This is a TA in teh LC Playbook course, which I'm not sure we have,
      # but we want to check non-student enrollments in LC Playbook.
      let(:user) { create :ta_user, section: lc_playbook_section }
      it_behaves_like 'not permitted'
    end
  end

  describe 'GET #show' do
    let(:lc_playbook_user) { create :lc_playbook_user, section: lc_playbook_section }
    let(:fellow_evaluation_submission) { create(
      :fellow_evaluation_submission,
      user: lc_playbook_user,
      course: lc_playbook_course,
    ) }

    subject {
      get(
        :show,
        params: {
          course_id: lc_playbook_course.id,
          id: fellow_evaluation_submission.id,
          lti_launch_id: @lti_launch.id,
        },
      )
    }

    shared_examples 'shows submission' do
      scenario 'displays confirmation message' do
        subject
        expect(response.body).to include("Thank you for submitting your fellow evaluation!")
      end
    end

    context 'as the LC' do
      let(:user) { lc_playbook_user }

      it_behaves_like 'valid request'
      it_behaves_like  'shows submission'
    end

    context 'as admin' do
      let(:user) { create :admin_user }
      it_behaves_like 'valid request'
      it_behaves_like  'shows submission'
    end

    context 'as not-enrolled' do
      let(:user) { create :registered_user }
      it_behaves_like  'not permitted'
    end
  end
end
