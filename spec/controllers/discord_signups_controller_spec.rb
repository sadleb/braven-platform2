require 'rails_helper'
require 'discordrb'
require 'discordrb/webhooks'
require 'salesforce_api'

RSpec.describe DiscordSignupsController, type: :controller do
  render_views

  let(:sf_client) { instance_double(SalesforceAPI) }
  let(:discordrb_api_user) { instance_double(Discordrb::API::User) }

  let(:course) { create :course }
  let(:user) { create :fellow_user }
  let(:section) { create :section, course: course }

  let!(:lti_launch) {
    create(
      :lti_launch_assignment,
      canvas_course_id: course.canvas_course_id,
      canvas_user_id: user.canvas_user_id,
    )
  }
  
  before :each do
    sign_in user
  end

  describe 'GET #launch' do
    let(:discord_user) { {}.to_json }
    subject { get :launch, params: { lti_launch_id: lti_launch.id, state: lti_launch.state }}

    before(:each) do
      allow(SalesforceAPI).to receive(:client).and_return(sf_client)
      allow(sf_client).to receive(:find_participant)
      .and_return(participant)
    end

    shared_examples 'renders initial steps' do
      it 'renders initial steps' do
        subject
        expect(response.body).to include('Step 1: Sign In or Register for Discord')
      end
    end

    context 'with TA Enrollment' do
      before(:each) do
        user.add_role RoleConstants::TA_ENROLLMENT, section
      end

      context 'with a real TA participant (has TA role and volunteer role)' do
        let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_real_ta)) }

        it_behaves_like 'renders initial steps'
      end

      context 'with a fake TA participant (has TA role, but non-TA volunteer role)' do
        let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_fake_ta)) }

        it 'renders the \'no discord\' page' do
          subject
          expect(response.body).to include ('Your enrollment type does not allow you to access this page.')
        end
      end
    end

    context 'with a student participant' do
      let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_fellow)) }

      before(:each) do
        user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      end

      it_behaves_like 'renders initial steps'
    end

    context 'with a valid discord_state' do
      let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_fellow)) }

      before(:each) do
        user.add_role RoleConstants::STUDENT_ENROLLMENT, section
        user.update!(discord_state: "teststate,#{lti_launch.id}")
      end

      it_behaves_like 'renders initial steps'

      it 'does not modify discord_state' do
        subject
        user.reload
        expect(user.discord_state).to eq("teststate,#{lti_launch.id}")
      end
    end

    context 'without discord_state' do
      let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_fellow)) }

      before(:each) do
        user.add_role RoleConstants::STUDENT_ENROLLMENT, section
        user.discord_state = nil
      end

      it 'sets the discord_state' do
        subject
        user.reload
        expect(user.discord_state).not_to eq(nil)
      end

      it_behaves_like 'renders initial steps'
    end

    context 'with an expired launch id in the discord_state' do
      let(:original_discord_state) { "teststate,#{LtiLaunch.last.id + 1}" }
      let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_fellow)) }

      before(:each) do
        user.add_role RoleConstants::STUDENT_ENROLLMENT, section
        user.update!(discord_state: original_discord_state)
      end

      it 'updates the discord_state' do
        subject
        user.reload
        expect(user.discord_state).not_to eq(original_discord_state)
      end

      it_behaves_like 'renders initial steps'
    end

    context 'with an expired discord_token' do
      let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_fellow)) }

      before(:each) do
        user.add_role RoleConstants::STUDENT_ENROLLMENT, section
        user.discord_expires_at = Time.now.utc - 1.week
      end

      it 'resets the discord_token to nil' do
        subject
        expect(user.discord_token).to eq(nil)
      end

      it_behaves_like 'renders initial steps'
    end

    context 'with no discord_token' do
      let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_fellow)) }

      before(:each) do
        user.add_role RoleConstants::STUDENT_ENROLLMENT, section
        user.update!(discord_token: nil)
      end

      it_behaves_like 'renders initial steps'
    end

    context 'with a discord_token that is raising Discordrb::Errors::UnknownError / Unauthorized' do
      let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_fellow)) }

      before(:each) do
        user.add_role RoleConstants::STUDENT_ENROLLMENT, section
        user.update!(discord_token: 'faketoken')
        stub_request(:get, "#{Discordrb::API.api_base}/users/@me").to_raise(Discordrb::Errors::UnknownError)
      end

      it 'resets the user\'s Discord token to nil' do
        subject
        expect(user.reload.discord_token).to eq(nil)
      end

      it 'redirects to discord signups launch page' do
        expect(subject).to redirect_to(launch_discord_signups_path(lti_launch_id: lti_launch.id))
      end

      it 'shows alert that something went wrong' do
        subject
        expect(flash[:alert]).to match /Something went wrong, please try authorizing again./
      end
    end

    context 'with a valid discord_token' do
      let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_fellow)) }

      before(:each) do
        user.update!(discord_token: 'faketoken')
        stub_request(:get, "#{Discordrb::API.api_base}/users/@me").to_return(body: discord_user)
        user.add_role RoleConstants::STUDENT_ENROLLMENT, section
      end

      context 'with a discord user that has no email' do
        let(:discord_user) { { id: "fakeid1", email: nil, verified: false }.to_json }

        it 'shows the claim account steps to add an email to the account' do
          subject
          expect(response.body).to include('Follow these instructions to set an email address')
        end
      end

      context 'with a discord user with an unverified email' do
        let(:discord_user) { { id: "fakeid1", email: "test@gmail.com", verified: false }.to_json }

        it 'shows the verify email steps' do
          subject
          expect(response.body).to include('Follow these instructions to verify the email associated with your Discord account')
        end
      end

      context 'with discord_user with a verified email' do
        let(:discord_user) { { id: 'fakeid1', email: 'test@gmail.com', username: 'test_user_name', verified: true }.to_json }
        let(:discord_server) { create(:discord_server, discord_server_id: participant.discord_server_id) }
        let(:user_in_discord_servers) { [{id: discord_server.discord_server_id}].to_json }

        before(:each) do
          stub_request(:get, "#{Discordrb::API.api_base}/users/@me/guilds").to_return(body: user_in_discord_servers)
          allow(Discordrb::API::Server).to receive(:add_member)
        end

        it 'shows the final instructions' do
          subject
          expect(response.body).to include('You\'re all set up with Discord!')
        end

        it 'shows the discord_user\'s email' do
          subject
          expect(response.body).to include('test@gmail.com')
        end

        it 'shows the discord_user\'s username' do
          subject
          expect(response.body).to include('test_user_name')
        end

        # note: test what error page this shows
        context 'without a discord_server_id' do
          before(:each) do
            participant.discord_server_id = nil
          end

          it 'raises an exception' do
            expect{ subject }.to raise_error(DiscordSignupsController::DiscordServerIdError)
          end
        end

        context 'without a discord_server record' do
          before :each do
            # Set a non-existant Discord server ID in the Participant record.
            participant.discord_server_id = build(:discord_server).discord_server_id
          end

          it 'raises an exception' do
            expect { subject }.to raise_error(DiscordSignupsController::DiscordServerIdError)
          end
        end

        context 'without user in server' do
          let(:webhook_client) { instance_double(Discordrb::Webhooks::Client, execute: nil) }
          let(:lti_advantage_api_client) { instance_double(LtiAdvantageAPI, create_score: nil) }
          let(:user_in_discord_servers) { [].to_json }

          before :each do
            allow(Discordrb::Webhooks::Client).to receive(:new).and_return(webhook_client)
            allow(LtiAdvantageAPI).to receive(:new).and_return(lti_advantage_api_client)
            allow(LtiScore).to receive(:new_full_credit_submission)
            allow(Discordrb::API::Server).to receive(:add_member)
            discord_server
          end

          it 'adds them' do
            subject
            expect(Discordrb::API::Server).to have_received(:add_member).once
          end

          it 'calls webhook' do
            subject
            expect(webhook_client).to have_received(:execute).once
          end

          context 'with student' do
            it 'sends lti score' do
              subject
              expect(LtiScore).to have_received(:new_full_credit_submission).once
              expect(lti_advantage_api_client).to have_received(:create_score).once
            end
          end

          context 'without student' do
            before :each do
              user.remove_role RoleConstants::STUDENT_ENROLLMENT, section
              user.remove_role RoleConstants::STUDENT_ENROLLMENT
              user.add_role RoleConstants::TA_ENROLLMENT, section
            end

            it 'does not send lti score' do
              subject
              expect(LtiScore).not_to have_received(:new_full_credit_submission)
              expect(lti_advantage_api_client).not_to have_received(:create_score)
            end
          end
        end

        context 'with user in server' do
          before :each do
            allow(Discordrb::API::Server).to receive(:add_member)
          end

          it 'does not add them' do
            subject
            expect(Discordrb::API::Server).not_to have_received(:add_member)
          end
        end
      end
    end
  end

  describe 'GET #oauth' do
    let(:params) { {} }

    subject { get :oauth, params: params }

    context 'with non-matching states' do
      let(:discord_state_db) { 'test,1' }
      let(:discord_state_param) { 'different,1' }
      let(:params) { { state: discord_state_param } }

      before :each do
        user.discord_state = discord_state_db
      end

      it 'raises error' do
        expect {
          subject
        }.to raise_error(SecurityError)
      end
    end

    context 'with matching states' do
      let(:lti_launch_id) { 1 }
      let(:discord_state) { "test,#{lti_launch_id}" }
      let(:params) { { state: discord_state } }
      let(:discord_token) { 'discord test token' }
      let(:discord_expires_in) { 604800 }
      let(:discord_token_response) { { access_token: discord_token, expires_in: discord_expires_in }.to_json }

      before :each do
        user.update!(discord_state: discord_state)
        stub_request(:post, DiscordSignupsController::DISCORD_API_TOKEN_URL).to_return(body: discord_token_response)
      end

      context 'with discord success' do
        it 'exchanges token' do
          subject
          expect(WebMock).to have_requested(:post, DiscordSignupsController::DISCORD_API_TOKEN_URL).once
        end

        it 'updates user discord_token / expires_at' do
          expect(user.discord_token).to eq(nil)
          expect(user.discord_expires_at).to eq(nil)
          subject
          user.reload
          expect(user.discord_token).to eq(discord_token)
          expect(user.discord_expires_at).not_to eq(nil)
        end

        it 'resets discord_state to empty' do
          subject
          user.reload
          expect(user.discord_state).to eq('')
        end

        it 'redirects to #launch' do
          expect(subject).to redirect_to(launch_discord_signups_path(lti_launch_id: lti_launch_id))
        end
      end

      context 'with discord error' do
        before :each do
          allow(Discordrb::API).to receive(:request).and_raise(Discordrb::Errors::UnknownError.new("test error"))
        end

        context 'with error param' do
          let(:params) { { state: discord_state, error: 'test error' } }

          it 'redirects' do
            expect(subject).to redirect_to(launch_discord_signups_path(lti_launch_id: lti_launch_id))
          end

          it 'shows alert' do
            subject
            expect(flash[:alert]).to match /Authorize/
          end
        end

        context 'without error param' do
          it 're-raises error' do
            expect {
              subject
            }.to raise_error(Discordrb::Errors::UnknownError)
          end
        end
      end

    end
  end

  describe 'GET #completed' do
    it 'renders completed page' do
      get :completed
      expect(response.body).to match /Complete/
    end
  end

  context 'when logged in as admin user' do
    let!(:user) { create :admin_user }
    let(:course) { create :course }
    let(:assignment_name) { DiscordSignupsController::DISCORD_ASSIGNMENT_NAME }
    let(:created_canvas_assignment) { build(:canvas_assignment, course_id: course.canvas_course_id, name: assignment_name) }
    let(:canvas_client) { double(CanvasAPI) }

    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
    end

    describe 'POST #publish' do

      context 'with valid params' do
        let(:valid_publish_params) { {course_id: course.id} }

        before(:each) do
          allow(canvas_client).to receive(:create_lti_assignment).and_return(created_canvas_assignment)
          allow(canvas_client).to receive(:update_assignment_lti_launch_url)
          post :publish, params: valid_publish_params
        end

        it 'flashes success message' do
          expect(flash[:notice]).to match /successfully published/
        end

        it 'redirects to edit page' do
          expect(response).to redirect_to(edit_course_path(course))
        end

        it 'calls the API correctly' do
          # Hardcoding the path so that if someone changes it they're forced to see this comment
          # and consider that it will break all previously published Discord Signups assignments.
          expect(canvas_client).to have_received(:create_lti_assignment)
            .with(course.canvas_course_id, assignment_name, nil, DiscordSignupsController::DISCORD_POINTS_POSSIBLE, true).once
          expect(canvas_client).to have_received(:update_assignment_lti_launch_url)
            .with(
              course.canvas_course_id,
              created_canvas_assignment['id'],
              /discord_signups\/launch/,
            ).once
        end

      end

    end # POST #publish

    describe 'POST #unpublish' do

      context 'with valid params' do
        let(:valid_unpublish_params) { {course_id: course.id, canvas_assignment_id: created_canvas_assignment['id']} }

        before(:each) do
          allow(canvas_client).to receive(:delete_assignment).and_return(created_canvas_assignment)
          delete :unpublish, params: valid_unpublish_params
        end

        it 'flashes success message' do
          expect(flash[:notice]).to match /successfully deleted/
        end

        it 'redirects to edit page' do
          expect(response).to redirect_to(edit_course_path(course))
        end

        it 'calls the API correctly' do
          expect(canvas_client).to have_received(:delete_assignment)
            .with(course.canvas_course_id, created_canvas_assignment['id'].to_s).once
        end

      end

    end # POST #unpublish

  end # logged in as admin user
end
