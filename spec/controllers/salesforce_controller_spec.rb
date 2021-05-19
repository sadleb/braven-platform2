require 'rails_helper'

RSpec.describe SalesforceController, type: :controller do
  render_views

  context 'for signed in user' do
    let!(:user) { create :admin_user }
    let(:sf_participants) { [] }
    let(:sf_program) { SalesforceAPI::SFProgram.new('00355500001iyvccccQ', 'Some Program', 'Some School', 28375) }
    let(:sf_client) { double(SalesforceAPI) }

    before(:each) do
      sign_in user
      allow(sf_client).to receive(:find_participants_by).with(program_id: sf_program.id).and_return(sf_participants)
      allow(SalesforceAPI).to receive(:client).and_return(sf_client)
    end

    describe 'GET #init_sync_from_salesforce_program' do
      subject(:show_init_sync) do
        get :init_sync_from_salesforce_program
      end

      it 'has a hidden param indicating that the user has not confirmed an "are you sure" message' do
        show_init_sync
        expect(response.body).to match(/<form.*<input value="true" type="hidden" name="not_confirmed" id="not_confirmed".*<\/form>/m)
      end
    end # POST #sync_from_salesforce_program

    describe 'GET #confirm_send_signup_emails' do

      subject(:show_confirm_emails) do
        get :confirm_send_signup_emails, params: { program_id: sf_program.id }
      end

      shared_examples 'confirm recipients before running sync' do
        it 'has a button to start the sync' do
          show_confirm_emails
          expect(response.body).to match(/#{Regexp.escape('<input type="submit" name="commit" value="Start Sync From Salesforce Process"')}/)
        end

        it 'starts the sync in "send signup emails" mode' do
          show_confirm_emails
          expect(response.body).to match(/#{Regexp.escape('<input value="true" type="hidden" name="send_signup_emails" id="send_signup_emails"')}/)
        end

        it 'starts the sync for the proper program' do
          show_confirm_emails
          expect(response.body).to match(/#{Regexp.escape("<input value=\"#{sf_program.id}\" type=\"hidden\" name=\"program_id\" id=\"program_id\"")}/)
        end

        # This isn't really a great test b/c the param is just missing, aka false. Putting it here just to signal the intention
        # that "send_signup_emails" needs a confirmation before it should run in that mode
        it 'starts the sync with confirmation that it should run' do
          show_confirm_emails
          expect(response.body).not_to match(/#{Regexp.escape('<input value="true" type="hidden" name="not_confirmed"')}/)
        end
      end

      context 'when Sync From Salesforce has run at a later point in time since the last new Participant was added' do
        let!(:fellow_user) { create :fellow_user }
        let(:already_synced_sf_participant) { create :salesforce_participant_fellow, :Email => fellow_user.email, :ContactId => fellow_user.salesforce_id }
        let(:already_synced_sf_participant_struct) { SalesforceAPI.participant_to_struct(already_synced_sf_participant) }
        let(:sf_participants) { [already_synced_sf_participant_struct] }

        it 'shows a message about no one receiving sign-up emails' do
          show_confirm_emails
          expect(response.body).to match(/No users will receive sign-up emails/)
        end

        it_behaves_like 'confirm recipients before running sync'
      end

      context 'when new Participants have been added after Sync From Salesforce has run' do
        let(:new_sf_participant) { create :salesforce_participant_fellow }
        let(:new_sf_participant_struct) { SalesforceAPI.participant_to_struct(new_sf_participant) }
        let(:sf_participants) { [new_sf_participant_struct] }

        it 'shows the new Participant in the list of folks who will get a sign-up email' do
          show_confirm_emails
          expect(response.body).to match(/These users will receive emails/)
          expect(response.body).to match(/th.*#{new_sf_participant_struct.first_name} #{new_sf_participant_struct.last_name}/)
          expect(response.body).to match(/<td>#{new_sf_participant_struct.email}<\/td>/)
        end

        it_behaves_like 'confirm recipients before running sync'
      end

    end # POST #confirm_send_signup_emails

    describe 'POST #sync_from_salesforce_program' do
      let(:send_signup_emails) { false }
      let(:staff_email) { 'user.running.sync@bebraven.org' }
      let(:base_params) { { program_id: sf_program.id, email: staff_email, send_signup_emails: send_signup_emails } }
      let(:params) { base_params }

      subject(:run_sync_from_salesforce) do
        post :sync_from_salesforce_program, params: params
      end

      shared_examples 'runs the sync' do
        it 'starts the sync in "send signup emails" mode for the proper program' do
          expect(SyncFromSalesforceProgramJob).to receive(:perform_later).with(sf_program.id, staff_email, send_signup_emails).once
          run_sync_from_salesforce
        end

        # This matters b/c we want to be able to give regional staff members the Role to be able to run
        # this but not give them full admin access.
        it 'redirects back to initial "Sync From Salesforce" page' do
          allow(SyncFromSalesforceProgramJob).to receive(:perform_later)
          run_sync_from_salesforce
          expect(response).to redirect_to(salesforce_sync_from_salesforce_program_path)
        end
      end

      context 'when sending signup emails' do
        let(:send_signup_emails) { true }

        context 'from the init sync page instead of the confirmation page' do
          let(:params) { base_params.merge({not_confirmed: true}) }
          it 'requires confirmation' do
            run_sync_from_salesforce
            expect(response).to redirect_to(salesforce_confirm_send_signup_emails_path(program_id: sf_program.id, email: staff_email))
          end
        end

        # Note: the confirm_send_signup_emails page doesn't pass a not_confirmed param which is what this mimics
        context 'from the confirmation page' do
          it_behaves_like 'runs the sync'
        end
      end

      context 'when not sending signup emails' do
        let(:send_signup_emails) { false }
        let(:params) { base_params.merge({not_confirmed: true}) }

        # No confirmation page needed, it just runs it.
        it_behaves_like 'runs the sync'
      end
    end # POST #sync_from_salesforce_program

  end # 'for signed in user'

  describe "GET #update_contacts" do
    let!(:access_token) { create :access_token }
    let(:token_owner_user) { access_token.user }
    let(:token_owner_user_role) { nil }
    let(:sync_contact_service) { double(SyncFromSalesforceContact, :run! => nil) }
    let(:canvas_client) { double(CanvasAPI, :change_user_login_email => nil, :create_user_email_channel => nil, :delete_user_email_channel => nil) }
    let(:delivery) { double('DummyDeliverer', deliver_now: nil) }
    let(:mailer) { double(SyncSalesforceContactToCanvasMailer, :failure_email => delivery ) }
    let(:new_email) { 'some_new_email@example.com' }
    let(:fellow_user) { create :fellow_user}
    let(:contact_to_update) { build(:salesforce_update_registered_contact, new_email: new_email, fellow_user: fellow_user) }

    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(SyncFromSalesforceContact).to receive(:new).and_return(sync_contact_service)
      allow(SyncSalesforceContactToCanvasMailer).to receive(:with).and_return(mailer)
    end

    context 'with valid Access Token' do

      subject(:post_update) do
        token_owner_user.add_role(token_owner_user_role) if token_owner_user_role
        request.headers.merge!('Access-Key' => access_token.key)
        post :update_contacts, body: contact_to_update.to_json, as: :json
      end

      it 'sets the current_user to the token owner' do
        expect{ post_update }.to raise_error(Pundit::NotAuthorizedError)
        expect(controller.current_user).to eq(token_owner_user)
      end

      shared_examples 'updates successfully' do
        it 'authenticates successfully' do
          post_update
          expect(response).to be_successful
        end

        it 'runs SyncFromSalesforceContact service' do
          post_update
          expect(SyncFromSalesforceContact).to have_received(:new).with(
            fellow_user,
            SalesforceAPI::SFContact.new(fellow_user.salesforce_id, new_email, fellow_user.first_name, fellow_user.last_name)
          ).once
          expect(sync_contact_service).to have_received(:run!).once
        end

        context 'when SyncFromSalesforceContact service fails' do
          # The endpoint is called from a Salesforce APEX class that is triggered using Proces Builder.
          # Returning a failure response to that side of the house isn't useful b/c you can't access those
          # logs without enabling trace logging and spending forever digging. The behavior is to email
          # the staff member and log stuff to Sentry/Honeycomb/the logs
          it 'emails the failure' do
            allow(sync_contact_service).to receive(:run!).and_raise(RestClient::Exception)
            expect{ post_update }.not_to raise_error(RestClient::Exception)
            expect(delivery).to have_received(:deliver_now).once
            expect(response).to be_successful
          end
        end
      end

      context 'with admin user token' do
        let(:token_owner_user_role) { RoleConstants::ADMIN }
        it_behaves_like 'updates successfully'
      end

      context 'with CanSyncFromSalesforce user token' do
        let(:token_owner_user_role) { RoleConstants::CAN_SYNC_FROM_SALESFORCE }
        it_behaves_like 'updates successfully'
      end

      context 'with nil role user token' do
        let(:token_owner_user_role) { nil }

        it 'is not authorized' do
          expect{ post_update }.to raise_error(Pundit::NotAuthorizedError)
        end
      end

    end

    context 'with invalid Access Token' do

      before(:each) do
        invalid_token_key = AccessToken.generate_key # Invalid b/c it's not saved to a record
        request.headers.merge!('Access-Key' => invalid_token_key)
        post :update_contacts, body: contact_to_update.to_json, as: :json
      end

      it 'does not set the current_user to the token owner' do
        expect(controller.current_user).to eq(nil)
      end

      it 'does not authenticate successfully' do
        expect(response).not_to be_successful
        expect(response).to have_http_status(401)
      end

    end

  end # POST #update_contacts

end
