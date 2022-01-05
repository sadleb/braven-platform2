# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DiscordServerChannelsController, type: :controller do
  render_views

  let(:user) { create(:admin_user) }
  let(:discord_server) { create(:discord_server) }
  let!(:discord_server_channel) { create(:discord_server_channel, discord_server: discord_server) }
  let!(:discord_server_channel_other_server) { create(:discord_server_channel) }

  before :each do
    sign_in user
  end

  describe 'GET #index' do

    before(:each) do
      get(
        :index,
        params: {
          discord_server_id: discord_server.id,
        },
        format: :json,
      )
    end

    it 'returns a success response' do
      expect(response).to be_successful
    end

    it 'shows the correct content' do
      parsed_body = JSON.parse(response.body)
      expect(parsed_body.count).to eq(1)
      expect(parsed_body[0]['name']).to eq(discord_server_channel.name)
    end
  end
end
