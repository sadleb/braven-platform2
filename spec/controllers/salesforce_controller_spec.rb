require 'rails_helper'

RSpec.describe SalesforceController, type: :controller do
  render_views

  let!(:access_token) { create :access_token }
  let(:token_owner_user) { access_token.user }
  let(:token_owner_user_role) { nil }
  let(:canvas_client) { double(CanvasAPI, :change_user_login_email => nil, :create_user_email_channel => nil, :delete_user_email_channel => nil) }
  let(:delivery) { double('DummyDeliverer', deliver_now: nil) }
  let(:mailer) { double(SyncSalesforceContactToCanvasMailer, :failure_email => delivery ) }
  let(:fellow_user) { create :fellow_user}
  let(:contact_to_update) { build(:salesforce_update_registered_contact, fellow_user: fellow_user).to_json }

  describe "POST #update_contacts" do

    before(:each) do
      allow(CanvasAPI).to receive(:client).and_return(canvas_client)
      allow(SyncSalesforceContactToCanvasMailer).to receive(:with).and_return(mailer)
    end

    context 'with valid Access Token' do

      subject(:post_update) do
        token_owner_user.add_role(token_owner_user_role) if token_owner_user_role
        request.headers.merge!('Access-Key' => access_token.key)
        post :update_contacts, body: contact_to_update, as: :json
      end

      it 'sets the current_user to the token owner' do
        expect{ post_update }.to raise_error(Pundit::NotAuthorizedError)
        expect(controller.current_user).to eq(token_owner_user)
      end

       context 'with admin user token' do
        let(:token_owner_user_role) { RoleConstants::ADMIN }

        it 'authenticates successfully' do
          post_update
          expect(response).to be_successful
        end
      end

      context 'with CanSyncFromSalesforce user token' do
        let(:token_owner_user_role) { RoleConstants::CAN_SYNC_FROM_SALESFORCE }

        it 'authenticates successfully' do
          post_update
          expect(response).to be_successful
        end
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
        post :update_contacts, body: contact_to_update, as: :json
      end

      it 'sets the current_user to the token owner' do
        expect(controller.current_user).to eq(nil)
      end

      it 'authenticates successfully' do
        expect(response).not_to be_successful
        expect(response).to have_http_status(401)
      end

    end

  end # POST #update_contacts

end
