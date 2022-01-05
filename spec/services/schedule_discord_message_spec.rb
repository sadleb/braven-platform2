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
  end
end
