# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncDiscordServers do

  let(:service) { SyncDiscordServers.new }

  describe ".run" do
    subject { service.run }

    let(:discord_servers) { [
      create(:discord_server),
      create(:discord_server),
      create(:discord_server),
    ] }

    it 'calls sync_server on all servers' do
      discord_servers.each do |server|
        expect(service).to receive(:sync_server).with(server).once
      end
      subject
    end
  end

  describe '.sync_server' do
    subject { service.sync_server(server) }

    let(:server) { create(:discord_server) }

    before :each do
      allow(service).to receive(:sync_server_channels)
      allow(service).to receive(:sync_server_roles)
    end

    it 'calls sync_server_channels once' do
      expect(service).to receive(:sync_server_channels).with(server).once
      subject
    end

    it 'calls sync_server_roles once' do
      expect(service).to receive(:sync_server_roles).with(server).once
      subject
    end
  end

  describe '.sync_server_channels' do
    subject { service.sync_server_channels(server) }

    let(:server) { create(:discord_server) }
    let(:response) { instance_double(RestClient::Response, body: channels.to_json) }
    let(:cohort_channel) { { id: 1, name: 'cohort-channel', position: 1, type: 0 } }
    let(:channel_category) { { id: 2, name: 'Channel Category', position: 2, type: 4 } }
    let(:text_channel) { { id: 3, name: 'text-channel', position: 3, type: 0 } }
    let(:channels) { [
      cohort_channel,
      channel_category,
      text_channel,
    ] }

    before :each do
      allow(Discordrb::API::Server).to receive(:channels).and_return(response)
    end

    context 'with existing channel' do
      let!(:existing_channel) {
        create(:discord_server_channel,
               discord_server_id: server.id,
               discord_channel_id: text_channel[:id].to_s,
               name: text_channel[:name] + '-old',
               position: text_channel[:position] + 10)
      }

      it 'updates existing channel' do
        subject
        existing_channel.reload
        expect(existing_channel.name).to eq(text_channel[:name])
        expect(existing_channel.position).to eq(text_channel[:position])
      end

      it 'skips cohort channels' do
        subject
        expect(DiscordServerChannel.find_by(name: cohort_channel[:name])).to eq(nil)
      end

      it 'skips non-text channels' do
        subject
        expect(DiscordServerChannel.find_by(name: channel_category[:name])).to eq(nil)
      end
    end

    context 'without existing channel' do
      it 'creates channel' do
        expect {
          subject
        }.to change(DiscordServerChannel, :count).by(1)
        expect(DiscordServerChannel.find_by(name: text_channel[:name])).not_to eq(nil)
      end
    end
  end

  describe '.sync_server_roles' do
    subject { service.sync_server_roles(server) }

    let(:server) { create(:discord_server) }
    let(:response) { instance_double(RestClient::Response, body: roles.to_json) }
    let(:cohort_role) { { id: 1, name: 'Cohort: Role' } }
    let(:everyone_role) { { id: 2, name: '@everyone' } }
    let(:generic_role) { { id: 3, name: 'generic role' } }
    let(:roles) { [
      cohort_role,
      everyone_role,
      generic_role,
    ] }

    before :each do
      allow(Discordrb::API::Server).to receive(:roles).and_return(response)
    end

    context 'with existing role' do
      let!(:existing_role) {
        create(:discord_server_role,
               discord_server_id: server.id,
               discord_role_id: generic_role[:id].to_s,
               name: generic_role[:name] + '-old')
      }

      it 'updates existing role' do
        subject
        existing_role.reload
        expect(existing_role.name).to eq(generic_role[:name])
      end

      it 'skips cohort roles' do
        subject
        expect(DiscordServerRole.find_by(name: cohort_role[:name])).to eq(nil)
      end

      it 'skips @everyone role' do
        subject
        expect(DiscordServerRole.find_by(name: everyone_role[:name])).to eq(nil)
      end
    end

    context 'without existing role' do
      it 'creates role' do
        expect {
          subject
        }.to change(DiscordServerRole, :count).by(1)
        expect(DiscordServerRole.find_by(name: generic_role[:name])).not_to eq(nil)
      end
    end
  end
end
