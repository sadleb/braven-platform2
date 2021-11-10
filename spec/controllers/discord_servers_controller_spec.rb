require 'rails_helper'

RSpec.describe DiscordServersController, type: :controller do
  render_views

  context "with normal signin" do
    let(:user) { create :admin_user }
    let!(:discord_server) { create :discord_server }

    before :each do
      sign_in user
    end

    describe "GET #index" do
      it "returns a success response" do
        get :index
        expect(response).to be_successful
      end

      it "lists servers" do
        get :index
        expect(response.body).to match /#{discord_server.name}/
        expect(response.body).to match /Open/
        expect(response.body).to match /Delete/
      end
    end

    describe "GET #new" do
      it "returns a success response" do
        get :new
        expect(response).to be_successful
      end

      it "includes a form" do
        get :new
        expect(response.body).to match /<form/
      end
    end

    describe "POST #create" do
      context "with invalid params" do
        it "raises an error when required param is missing" do
          expect {
            post :create
          }.to raise_error ActionController::ParameterMissing
        end
      end

      context "with valid params" do
        let(:create_server) { post :create, params: {
          discord_server: {
            name: 'test name',
            discord_server_id: "#{discord_server.discord_server_id}99",
            webhook_url: "#{DiscordServer::WEBHOOK_URL_BASE}/99/testtoken"
          }
        } }

        it "redirects to index" do
          expect(create_server).to redirect_to discord_servers_path
        end

        it "creates discord server" do
          expect { create_server }.to change { DiscordServer.count }.by(1)
        end

      end
    end

    describe "DELETE #destroy" do
      context "with invalid params" do
        it "raises an error when required param is missing" do
          expect {
            delete :destroy
          }.to raise_error ActionController::UrlGenerationError
        end
      end

      context "with valid params" do
        it "redirects to index" do
          delete :destroy, params: { id: discord_server.id }
          expect(response).to redirect_to discord_servers_path
        end

        it "deletes specified server" do
          expect {
            delete :destroy, params: { id: discord_server.id }
          }.to change { DiscordServer.count }.by(-1)
        end
      end
    end
  end

end
