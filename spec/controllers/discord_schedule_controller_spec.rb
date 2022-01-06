require 'rails_helper'

RSpec.describe DiscordScheduleController, type: :controller do
  render_views

  context "with normal signin" do
    let(:user) { create :admin_user }
    let(:discord_server) { create :discord_server }
    let(:discord_server_channel) { create(:discord_server_channel, discord_server: discord_server) }
    let(:message) { 'test-msg' }
    let(:scheduled_set) { instance_double(Sidekiq::ScheduledSet,
      map: job_maps,
      find_job: job,
    ) }
    let(:job_maps) { [
      { at: 3.days.from_now, info: {
        'arguments' => [discord_server.discord_server_id, 'test-channel', message],
        'job_class' => 'SendDiscordMessageJob',
      }, id: 'fake' }
    ] }
    let(:job) { instance_double(Sidekiq::SortedEntry, delete: nil, jid: 'fake-jid') }

    before :each do
      sign_in user

      allow(Sidekiq::ScheduledSet).to receive(:new).and_return(scheduled_set)
    end

    describe "GET #index" do
      it "returns a success response" do
        get :index
        expect(response).to be_successful
      end

      it "lists scheduled jobs" do
        get :index
        expect(response.body).to match /<h2.*>Server: #{discord_server.name}/
        expect(response.body).to match /#test-channel/
        expect(response.body).to match /test-msg/
      end

      context 'with role @mention in message' do
        let(:role) { create(:discord_server_role, discord_server: discord_server) }
        let(:message) { "test <@&#{role.discord_role_id}> test" }

        it 'converts role mentions into human-readable' do
          get :index
          expect(response.body).to match /test @#{role.name} test/
        end
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
        let(:create_job) { post :create, params: {
          server_id: discord_server.id,
          channel_id: discord_server_channel.id,
          message: 'test-msg',
          datetime: '2991-09-23T22:45',
          timezone: 'America/Los_Angeles',
        } }

        it "redirects to index" do
          expect(create_job).to redirect_to discord_schedule_index_path
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
          delete :destroy, params: { id: job.jid }
          expect(response).to redirect_to discord_schedule_index_path
        end

        it "deletes specified job" do
          delete :destroy, params: { id: job.jid }
          expect(job).to have_received(:delete).once
        end
      end
    end
  end

end
