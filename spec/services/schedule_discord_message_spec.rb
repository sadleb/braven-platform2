# frozen_string_literal: true

require 'rails_helper'

require 'discord_bot'

RSpec.describe ScheduleDiscordMessage do
  describe '#run' do
    subject { @service.run }

    let(:discord_server) { create(:discord_server) }
    let(:discord_server_channel) { create(:discord_server_channel, discord_server: discord_server) }
    let(:channel_id) { discord_server_channel.id }
    let(:message) { 'test message' }
    let(:datetime) { '2991-09-23T22:45' }
    let(:timezone) { 'America/Los_Angeles' }
    let(:configured_job) { instance_double(ActiveJob::ConfiguredJob) }

    before :each do
      @service = ScheduleDiscordMessage.new(
        discord_server.id,
        channel_id,
        message,
        datetime,
        timezone
      )
    end

    it 'schedules delayed job based on params' do
      expect(configured_job).to receive(:perform_later)
        .with(discord_server.discord_server_id.to_i, discord_server_channel.name, message)
      expect(SendDiscordMessageJob).to receive(:set)
        .with(wait_until: anything)
        .and_return(configured_job)
      subject
    end

    context 'with all-cohort-channels shortcut' do
      let(:channel_id) { COHORT_CHANNEL_PREFIX }

      it 'sends cohort channel prefix as channel name' do
        expect(configured_job).to receive(:perform_later)
          .with(discord_server.discord_server_id.to_i, COHORT_CHANNEL_PREFIX, message)
        expect(SendDiscordMessageJob).to receive(:set)
          .with(wait_until: anything)
          .and_return(configured_job)
        subject
      end
    end

    context 'with role @mentions' do
      let(:role1) { create(:discord_server_role, discord_server: discord_server) }
      let(:role2) { create(:discord_server_role, discord_server: discord_server) }
      let(:message) { "test message with mentions @#{role1.name}, @#{role2.name} @everyone @notreal" }

      it 'converts role mentions to proper format' do
        expect(configured_job).to receive(:perform_later)
          .with(discord_server.discord_server_id.to_i, discord_server_channel.name,
                "test message with mentions <@&#{role1.discord_role_id}>, <@&#{role2.discord_role_id}> @everyone @notreal")
        expect(SendDiscordMessageJob).to receive(:set)
          .with(wait_until: anything)
          .and_return(configured_job)
        subject
      end
    end
  end

  describe '.convert_role_mentions' do
    subject { ScheduleDiscordMessage.convert_role_mentions(discord_server, message) }

    let(:discord_server) { create(:discord_server) }
    let(:role1) { create(:discord_server_role, discord_server: discord_server) }
    let(:role_short) { create(:discord_server_role, discord_server: discord_server, name: 'test') }
    let(:role_long) { create(:discord_server_role, discord_server: discord_server, name: 'test longer name') }

    context 'with lots of mentions' do
      let(:message) { "test @#{role1.name} @#{role_long.name} @#{role_short.name} @notreal test" }

      it 'replaces role names with ids correctly' do
        expect(subject).to eq("test <@&#{role1.discord_role_id}> <@&#{role_long.discord_role_id}> <@&#{role_short.discord_role_id}> @notreal test")
      end
    end

    context 'with no mentions' do
      let(:message) { 'test no mentions' }

      it 'returns message unchanged' do
        expect(subject).to eq(message)
      end
    end

    context 'with no role mentions' do
      let(:message) { 'test no role mentions but @everyone non role @mentions' }

      it 'returns message unchanged' do
        expect(subject).to eq(message)
      end
    end
  end
end
