require 'rails_helper'
require 'discord_bot'

RSpec.describe DiscordBot do

  WebMock.disable_net_connect!

  let(:bot) { DiscordBot.new(token: 'fake', enabled: true) }
  let(:discordrb_bot) { instance_double(Discordrb::Bot) }

  before :each do
    allow(Discordrb::Bot).to receive(:new).and_return(discordrb_bot)
  end

  describe '.run' do
    subject { bot.run }

    before :each do
      allow(discordrb_bot).to receive(:ready)
      allow(discordrb_bot).to receive(:server_create)
      allow(discordrb_bot).to receive(:message)
      allow(discordrb_bot).to receive(:member_join)
      allow(discordrb_bot).to receive(:run)

      subject
    end

    it 'calls Discordrb::Bot.run' do
      expect(discordrb_bot).to have_received(:run)
    end
  end

  # Event handlers
  describe '.on_ready' do
    subject { bot.on_ready(nil) }

    before :each do
      allow(bot).to receive(:sync_salesforce)
      allow(discordrb_bot).to receive(:servers)
    end

    context 'with sync_and_exit=false' do
      it 'inits invite cache' do
        expect(bot).to receive(:init_invite_uses_cache)
        subject
      end

      it 'does not run sync' do
        expect(bot).not_to receive(:sync_salesforce)
      end
    end

    context 'with sync_and_exit=true' do
      let(:bot) { DiscordBot.new(token: 'fake', enabled: true, sync_and_exit: true) }

      # Note: we test the 'exit' behavior in the same specs because running `exit`
      # outside of the `expect to raise_error` block makes rspec break.
      it 'does not init invite cache; exits' do
        expect(bot).not_to receive(:init_invite_uses_cache)
        expect {
          subject
        }.to raise_error(SystemExit)
      end

      it 'runs sync; exits' do
        expect(bot).to receive(:sync_salesforce)
        expect {
          subject
        }.to raise_error(SystemExit)
      end
    end
  end

  describe '.on_server_create' do
    subject { bot.on_server_create(event) }

    let(:server) { instance_double(Discordrb::Server, id: 'fake-server-id') }
    let(:event) { instance_double(Discordrb::Events::ServerCreateEvent, server: server) }

    before :each do
      allow(discordrb_bot).to receive(:servers).and_return({server.id => server})
      allow(bot).to receive(:send_to_general)
      allow(bot).to receive(:init_invite_uses_cache)
    end

    it 'updates local servers cache' do
      expect(bot.instance_variable_get(:@servers)).to eq({})
      subject
      expect(bot.instance_variable_get(:@servers)).to eq({server.id => server})
    end

    it 'updates local invites cache' do
      expect(bot).to receive(:init_invite_uses_cache)
      subject
    end

    it 'messages the general channel' do
      expect(bot).to receive(:send_to_general).with(server.id, anything)
      subject
    end
  end

  describe '.on_member_join' do
    subject { bot.on_member_join(event) }

    let(:server) { instance_double(Discordrb::Server, id: 'fake-server-id') }
    let(:user) { instance_double(Discordrb::User, id: 'fake-user-id', username: 'fake-username', discriminator: 1234) }
    let(:member) { instance_double(Discordrb::Member, id: 'fake-member-id') }
    let(:event) { instance_double(Discordrb::Events::ServerMemberAddEvent, server: server, member: member) }
    let(:invite) { instance_double(Discordrb::Invite, code: 'fake-invite-code') }

    before :each do
      member.instance_variable_set(:@user, user)
      allow(bot).to receive(:find_used_invite).and_return(invite)
      allow(DiscordBot).to receive(:configure_member)
    end

    it 'tries to find the used invite' do
      expect(bot).to receive(:find_used_invite).with(server)
      subject
    end

    it 'configures the new member' do
      expect(DiscordBot).to receive(:configure_member).with(member, invite)
      subject
    end

    context 'with no invite found' do
      it 'exits before configuring member' do
        allow(bot).to receive(:find_used_invite).and_return(nil)
        expect(DiscordBot).not_to receive(:configure_member)
        subject
      end
    end
  end

  # Invites
  describe '.init_invite_uses_cache' do
  end

  describe '.find_used_invite' do
  end

  # Salesforce
  describe '.sync_salesforce' do
  end

  # Configure member
  describe 'self.configure_member' do
  end

  # Create invite
  describe '.create_invite' do
  end

  # Compute from Participant
  describe 'self.compute_nickname' do
  end

  describe 'self.compute_participant_role' do
  end

  describe 'self.compute_cohort_schedule_role' do
  end

  describe 'self.compute_cohort_role' do
  end

  # Roles/Channels
  describe 'self.get_role' do
  end

  describe 'self.get_or_create_cohort_role' do
  end

  describe 'self.configure_cohort_channel' do
  end
end

# Disable bot at_exit handler in specs, to stop rspec from failing.
class DiscordBot
private
  def shut_down
  end
end
