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

    describe 'GET #init_sync_salesforce_program' do
      subject(:show_init_sync) do
        get :init_sync_salesforce_program
      end
    end # POST #sync_salesforce_program

    describe 'POST #sync_salesforce_program' do
      let(:force_zoom_update) { false }
      let(:force_canvas_update) { false }
      let(:staff_email) { 'user.running.sync@bebraven.org' }
      let(:base_params) { { program_id: sf_program.id, email: staff_email, force_zoom_update: force_zoom_update } }
      let(:params) { base_params }

      subject(:run_sync_from_salesforce) do
        post :sync_salesforce_program, params: params
      end

      shared_examples 'runs the sync' do
        it 'starts the sync in "send signup emails" mode for the proper program' do
          expect(SyncSalesforceProgramJob).to receive(:perform_async).with(sf_program.id, staff_email, force_canvas_update, force_zoom_update).once
          run_sync_from_salesforce
        end

        # This matters b/c we want to be able to give regional staff members the Role to be able to run
        # this but not give them full admin access.
        it 'redirects back to initial "Sync From Salesforce" page' do
          allow(SyncSalesforceProgramJob).to receive(:perform_async)
          run_sync_from_salesforce
          expect(response).to redirect_to(salesforce_sync_salesforce_program_path)
        end
      end

      context 'when forcing Zoom update' do
        let(:force_zoom_update) { true }
        it_behaves_like 'runs the sync'
      end

      context 'when not forcing Zoom update' do
        let(:force_zoom_update) { false }
        it_behaves_like 'runs the sync'
      end
    end # POST #sync_salesforce_program

  end # 'for signed in user'

end
