require 'rails_helper'

RSpec.describe AcceleratorSurveySubmissionsController, type: :controller do
  render_views

  let(:user) { create :fellow_user }
  let(:course) { create :course }
  let(:section) { create :section, course: course }
  let(:accelerator_survey_submission) { build(
    :accelerator_survey_submission,
    user: user,
    course: course,
  ) }

  let(:lti_launch) {
    create(
      :lti_launch_assignment,
      canvas_user_id: user.canvas_user_id,
      course_id: course.canvas_course_id,
    )
  }

  let(:lti_advantage_api) { double(LtiAdvantageAPI) }
  let(:salesforce_api) { double(SalesforceAPI) }
  let(:form_assembly_client) { double(FormAssemblyAPI) }

  before(:each) do
    user.add_role RoleConstants::STUDENT_ENROLLMENT, section
    sign_in user
    allow(LtiAdvantageAPI).to receive(:new).and_return(lti_advantage_api)
    allow(SalesforceAPI).to receive(:client).and_return(salesforce_api)
    allow(FormAssemblyAPI).to receive(:client).and_return(form_assembly_client)
  end

  describe 'GET #completed' do
    subject { get :completed, params: { state: lti_launch.state } }

    it 'returns a success response' do
      expect(response).to be_successful
    end
  end

  shared_examples 'checks for previous submission' do
    scenario 'checks Canvas LTI Advantage API for a score' do
      expect(lti_advantage_api).to have_received(:get_result).once
    end
  end

  describe 'GET #new' do
    context 'valid parameters' do
      let(:form_assembly_info) { build(:salesforce_fellow_form_assembly_info_record) }
      let(:form_head) {
        '<meta name="fake" content="fake">' \
        '<script type="text/javascript">fakeJS();</script>'
      }
      let(:form_body) {
        '<form method="post" action="https://braven.tfaforms.net/responses/processor">' \
          '<input type="text" id="tfa_8" name="tfa_8" value="" title="Fake Field">' \
        '</form>'
      }

      before(:each) do
        allow(lti_advantage_api)
          .to receive(:get_result)
          .and_return(previous_submission)
        allow(salesforce_api)
          .to receive(:get_fellow_form_assembly_info)
          .and_return(:form_assembly_info)
        allow(salesforce_api).to receive(:get_participant_id)
        allow(form_assembly_client)
          .to receive(:get_form_head_and_body)
          .and_return([form_head, form_body])
        get :new, params: { type: type, state: lti_launch.state }
      end

      ['Pre', 'Post'].each do | type |
        context 'unsubmitted' do
          let(:previous_submission) { false }
          let(:type) { type }

          it_behaves_like 'checks for previous submission'

          # These tests are duplicated from WaiverSubmissionsController
          # because both controllers use FormAssemblyController.
          it 'returns a success response' do
            expect(response).to be_successful
          end

          it 'adds the referrer policy to <head>' do
            # Note: the trailing "m" option makes the ".*" match newlines
            expect(response.body).to match /<head>.*<meta name="referrer" content="no-referrer-when-downgrade">.*<\/head>/m
          end

          it 'adds the hidden state <input> element to the form' do
            expect(response.body).to match /<form.*<input type="hidden" value="#{Regexp.escape(lti_launch.state)}" name="state" id="state">.*<\/form>/m
          end

          it 'allows unsafe-eval for FormAssembly in the content_security_policy' do
            # Accessing the script_src a second time returns nil. Not sure why. Just store it in a var.
            script_csp = response.request.content_security_policy.script_src
            expect(script_csp[0]).to eq(Rails.application.secrets.form_assembly_url + ":*")
            expect(script_csp[1]).to eq("'unsafe-eval'")
          end
        end

        context 'previously submitted' do
          let(:previous_submission) { true }
          let(:type) { type }

          it_behaves_like 'checks for previous submission'

          it 'redirects to #completed' do
            url = send(
              "completed_#{type.downcase}accelerator_survey_submissions_url",
              state: lti_launch.state,
            )
            expect(response).to redirect_to(url)
          end
        end
      end
    end

    context 'invalid parameters' do
      it 'raises an error' do
        [
          { type: 'Pre' }, # missing state
          { state: lti_launch.state }, # missing type
          { state: lti_launch.state, type: 'Foo' }, # invalid type
        ].each do | invalid_params |
          expect { get :new, params: invalid_params }. to raise_error
        end
      end
    end
  end

  describe 'POST #create' do
    before(:each) do
      allow(LtiScore).to receive(:new_full_credit_submission)
      allow(lti_advantage_api)
        .to receive(:get_result)
        .and_return(previous_submission)
      allow(lti_advantage_api)
        .to receive(:create_score)
      post :create, params: { type: type, state: lti_launch.state }
    end

    context 'valid parameters' do
      ['Pre', 'Post'].each do | type |
        context 'new submission' do
          let(:previous_submission) { false }
          let(:type) { type }

          it_behaves_like 'checks for previous submission'

          it 'gives full credit to the fellow' do
            submission_url = send(
              "completed_#{type.downcase}accelerator_survey_submissions_url",
              protocol: 'https',
            )
            expect(LtiScore).to have_received(:new_full_credit_submission)
              .with(user.canvas_user_id, submission_url)
              .once
          end

          it 'creates the score in Canvas' do
            expect(lti_advantage_api).to have_received(:create_score).once
          end

          it 'redirects to #completed' do
            url = send(
              "completed_#{type.downcase}accelerator_survey_submissions_path",
              state: lti_launch.state
            )
            expect(response).to redirect_to(url)
          end
        end

        context 'existing submission' do
          let(:previous_submission) { true }
          let(:type) { type }

          it_behaves_like 'checks for previous submission'

          it 'does not create another score' do
            expect(lti_advantage_api).not_to have_received(:create_score)
          end
        end
      end
    end
  end
end
