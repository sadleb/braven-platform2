require 'rails_helper'

RSpec.describe WaiverSubmissionsController, type: :controller do
  render_views


  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # WaiversController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  context 'when logged in as fellow' do
    let(:course) { create :course }
    let(:section) { create(:section, course: course) }
    let!(:fellow_user) { create(:fellow_user, section: section) }
    let(:lti_launch) {
      create( :lti_launch_assignment,
        canvas_user_id: fellow_user.canvas_user_id,
        canvas_course_id: course.canvas_course_id
      )
    }

    before(:each) do
      allow(LtiLaunch).to receive(:from_id)
        .with(fellow_user, lti_launch.id)
        .and_return(lti_launch)
      sign_in fellow_user
    end

    context '#launch' do
      let(:waivers_submission_result) { nil }
      let(:lti_advantage_api) { double(LtiAdvantageAPI, :get_result => nil) }

      before(:each) do
        allow(lti_advantage_api).to receive(:get_result).and_return(waivers_submission_result)
        allow(LtiAdvantageAPI).to receive(:new).and_return(lti_advantage_api)
        get :launch, params: { lti_launch_id: lti_launch.id }, session: valid_session
      end

      it 'returns a success response' do
        expect(response).to be_successful
      end

      it 'looks for an existing Canvas waiver submission' do
        expect(lti_advantage_api).to have_received(:get_result).once
      end

      context 'when waivers havent been signed' do
        it 'shows the button to launch the waivers' do
          new_waivers_regex = "/waiver_submissions/new?lti_launch_id=#{lti_launch.id}"
          expect(response.body).to match /<a href=".*#{Regexp.escape(new_waivers_regex)}"/
        end
      end

      context 'when waivers are already signed' do
        let(:waivers_submission_result) { build(:lti_result) }
        it 'redirects to completed page' do
          expect(response).to redirect_to completed_waiver_submissions_path(lti_launch_id: lti_launch.id)
        end
      end
    end

    context '#new' do
      let(:participant_id) { 'a2X11000000lakXEAQ' }
      let(:form_head) {
        '<meta name="fake" content="fake">' \
        '<script type="text/javascript">fakeJS();</script>'
      }
      let(:form_body) {
        '<form method="post" action="https://braven.tfaforms.net/responses/processor">' \
          '<input type="text" id="tfa_8" name="tfa_8" value="" title="Fake Field">' \
        '</form>'
      }

      let(:fa_client) { double(FormAssemblyAPI) }
      before(:each) do
        allow(FormAssemblyAPI).to receive(:client).and_return(fa_client)
      end

      context 'for initial form' do
        let(:sf_form_assembly_info) { build(:salesforce_fellow_form_assembly_info_record) }
        let(:sf_client) { double(SalesforceAPI, :get_fellow_form_assembly_info => nil) }

        before(:each) do
          allow(sf_client).to receive(:get_fellow_form_assembly_info).and_return(sf_form_assembly_info)
          allow(sf_client).to receive(:get_participant_id).and_return(participant_id)
          allow(SalesforceAPI).to receive(:client).and_return(sf_client)
          allow(fa_client).to receive(:get_form_head_and_body).and_return([form_head, form_body])
          get :new, params: { lti_launch_id: lti_launch.id }, session: valid_session
        end

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

        it 'allows unsafe-eval and unsafe-inline for FormAssembly in the content_security_policy' do
          # Accessing the script_src a second time returns nil. Not sure why. Just store it in a var.
          script_csp = response.request.content_security_policy.script_src
          expect(script_csp[0]).to eq(Rails.application.secrets.form_assembly_url + ":*")
          expect(script_csp[1]).to eq("'unsafe-eval'")
          expect(script_csp[2]).to eq("'unsafe-inline'")
        end

      end # 'for initial form'

      context 'for subsequent forms in the flow' do
        before(:each) do
          allow(SalesforceAPI).to receive(:client).and_raise("This shouldnt happen")
          allow(LtiAdvantageAPI).to receive(:new).and_raise("This shouldnt happen")
          allow(fa_client).to receive(:get_next_form_head_and_body).and_return([form_head, form_body])

          get :new, params: { lti_launch_id: lti_launch.id, tfa_next: 'some/path/to/get/the/next/form' }, session: valid_session
        end

        it 'doesnt hit the SalesforceAPI' do
          expect(SalesforceAPI).not_to have_received(:client)
        end

        it 'doesnt hit the LtiAdvantageAPI' do
          expect(LtiAdvantageAPI).not_to have_received(:new)
        end

        it 'adds the referrer policy to <head>' do
          # Note: the trailing "m" option makes the ".*" match newlines
          expect(response.body).to match /<head>.*<meta name="referrer" content="no-referrer-when-downgrade">.*<\/head>/m
        end

        it 'adds the hidden state <input> element to the form' do
          expect(response.body).to match /<form.*<input type="hidden" value="#{Regexp.escape(lti_launch.state)}" name="state" id="state">.*<\/form>/m
        end

       end # 'for subsequent forms in the flow'

    end # '#new'

    context '#create' do
      let(:lti_score_response) { build(:lti_score_response) }
      let(:lti_score_request) { build(:lti_score) }
      let(:lti_advantage_api) { double(LtiAdvantageAPI) }

      before(:each) do
        allow(lti_advantage_api).to receive(:create_score).and_return(lti_score_response)
        allow(LtiAdvantageAPI).to receive(:new).and_return(lti_advantage_api)
        allow(LtiScore).to receive(:new_full_credit_submission)
          .with(fellow_user.canvas_user_id, completed_waiver_submissions_url(protocol: 'https')).and_return(lti_score_request)

        post :create, params: { lti_launch_id: lti_launch.id }, session: valid_session
      end

      it 'returns a success response' do
        expect(response).to be_successful
      end

      it 'submits the Canvas assignment' do
        expect(lti_advantage_api).to have_received(:create_score).with(lti_score_request).once
      end

      it 'shows the thank you page with message about next steps' do
        expect(response.body).to match /Waivers Submitted - One More Step/
        expect(response.body).to match /Thank you/
        expect(response.body).to match /#{Regexp.escape('immediately <strong>check your email and spam</strong>')}/
      end
    end # '#create'

    context '#completed' do
      it 'shows the thank you page' do
        get :completed, params: { lti_launch_id: lti_launch.id }, session: valid_session
        expect(response.body).to match /Thank you/
      end

      it 'shows message about still needing to do email verification if they didnt' do
        get :completed, params: { lti_launch_id: lti_launch.id }, session: valid_session
        expect(response.body).to match(/Please check your email and spam folder for a link to verify your waivers if you haven't already/)
      end
    end # '#completed'

  end # 'when logged in as fellow'

end
