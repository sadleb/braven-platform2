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

      it 'alerts on unconfigured members' do
        expect(bot).to receive(:alert_on_unconfigured_members)
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

  describe '.on_message' do
    subject { bot.on_message(event) }

    let(:message_content) { 'test message' }
    let(:server) { instance_double(Discordrb::Server, id: 'fake-server-id') }
    let(:user) { instance_double(Discordrb::User, id: 'fake-user-id', username: 'fake-username', discriminator: 1234) }
    let(:member) { instance_double(Discordrb::Member, id: 'fake-member-id', roles: roles, webhook?: false) }
    let(:message) { instance_double(Discordrb::Message, content: message_content, author: member, respond: nil) }
    let(:event) { instance_double(Discordrb::Events::MessageEvent, server: server, author: member, message: message) }
    let(:roles) { [] }

    before :each do
      member.instance_variable_set(:@user, user)
      allow(bot).to receive(:process_admin_command)
    end

    context 'with message that looks like command' do
      let(:message_content) { "#{BOT_COMMAND_KEY}test command" }

      context 'with message from admin' do
        let(:roles) { [
          instance_double(Discordrb::Role, name: ADMIN_ROLES.first),
        ] }

        it 'processes message as admin command' do
          expect(bot).to receive(:process_admin_command).with(event).once
          subject
        end
      end

      context 'with message from webhook' do
        let(:member) { instance_double(Discordrb::Member, id: 'fake-member-id', webhook?: true) }

        it 'processes message as admin command' do
          expect(bot).to receive(:process_admin_command).with(event).once
          subject
        end
      end

      context 'with message from non-admin and non-webhook' do
        let(:roles) { [
          instance_double(Discordrb::Role, name: 'Fellow'),
        ] }

        it 'ignores message' do
          expect(bot).not_to receive(:process_admin_command)
          expect(message).not_to receive(:respond)
          subject
        end
      end
    end

    context 'with message that does not look like command' do
      context 'with message from admin' do
        let(:roles) { [
          instance_double(Discordrb::Role, name: ADMIN_ROLES.first),
        ] }

        it 'ignores message' do
          expect(bot).not_to receive(:process_admin_command)
          expect(message).not_to receive(:respond)
          subject
        end
      end
    end
  end

  # Invites
  describe '.init_invite_uses_cache' do
    subject { bot.init_invite_uses_cache }

    let(:server1) { instance_double(Discordrb::Server, id: 'fake-server-id1', invites: [invite1]) }
    let(:server2) { instance_double(Discordrb::Server, id: 'fake-server-id2', invites: [invite2, invite3]) }
    let(:invite1) { instance_double(Discordrb::Invite, code: 'fake-invite-code1', uses: 0) }
    let(:invite2) { instance_double(Discordrb::Invite, code: 'fake-invite-code2', uses: 1) }
    let(:invite3) { instance_double(Discordrb::Invite, code: 'fake-invite-code3', uses: 0) }

    before :each do
      bot.instance_variable_set(:@servers, {
        server1.id => server1,
        server2.id => server2,
      })
    end

    it 'fills the invites cache' do
      expect(bot.instance_variable_get(:@invites)).to eq({})
      subject
      expect(bot.instance_variable_get(:@invites)).to eq({
        server1.id => {
          invite1.code => invite1.uses,
        },
        server2.id => {
          invite2.code => invite2.uses,
          invite3.code => invite3.uses,
        },
      })
    end
  end

  describe '.find_used_invite' do
    subject { bot.find_used_invite(server1) }

    let(:server1) { instance_double(Discordrb::Server, id: 'fake-server-id1', invites: [invite1, invite2]) }
    let(:server2) { instance_double(Discordrb::Server, id: 'fake-server-id2', invites: [invite3]) }
    let(:invite1) { instance_double(Discordrb::Invite, code: 'fake-invite-code1', uses: 0) }
    let(:invite2) { instance_double(Discordrb::Invite, code: 'fake-invite-code2', uses: 0) }
    let(:invite3) { instance_double(Discordrb::Invite, code: 'fake-invite-code3', uses: 0) }

    before :each do
      bot.init_invite_uses_cache
    end

    context 'with no used invite' do
      it 'returns nil' do
        expect(subject).to eq(nil)
      end
    end

    context 'with 1 used invite' do
      before :each do
        allow(invite2).to receive(:uses).and_return(1)
      end

      it 'returns the used invite' do
        expect(subject).to eq(invite2)
      end
    end

    context 'with multiple used invites' do
      before :each do
        allow(invite1).to receive(:uses).and_return(1)
        allow(invite2).to receive(:uses).and_return(1)
      end

      it 'returns nil' do
        expect(subject).to eq(nil)
      end

      it 'sends an alert' do
        expect(Honeycomb).to receive(:add_field).with('alert.multiple_invites_used', anything)
        subject
      end

      it 'updates the cache' do
        expect(bot).to receive(:init_invite_uses_cache)
        subject
      end
    end
  end

  # Salesforce
  describe '.sync_salesforce' do
    subject { bot.sync_salesforce }

    let(:member) { instance_double(Discordrb::Member, id: 'fake-member-id') }
    let(:invite) { instance_double(Discordrb::Invite, code: participant1_with_discord.discord_invite_code, delete: nil) }
    let(:server) { instance_double(Discordrb::Server, id: program1_with_discord['Discord_Server_ID__c'].to_i, invites: [invite]) }
    let(:programs) { create(:salesforce_current_and_future_programs, canvas_course_ids: [1, 2]) }
    let(:program1_with_discord) { create(:salesforce_program_record, program_id: programs['records'][0]['Id']) }
    let(:program2_without_discord) { create(:salesforce_program_record, program_id: programs['records'][1]['Id'], discord_server_id: nil) }
    let(:participant1_with_discord) { SalesforceAPI.participant_to_struct(create(:salesforce_participant, program_id: program1_with_discord['Id'])) }
    let(:participant2_without_discord) { SalesforceAPI.participant_to_struct(create(:salesforce_participant, program_id: program1_with_discord['Id'], discord_invite_code: nil)) }
    let(:participant3_with_discord) { SalesforceAPI.participant_to_struct(create(:salesforce_participant, program_id: program2_without_discord['Id'])) }
    let(:participant3_id_with_discord) { "a2Y17000003WLxqXYZ" }
    let(:contact1_with_discord) { create(:salesforce_contact) }
    let(:contact2_without_discord) { create(:salesforce_contact, discord_user_id: nil) }
    let(:program1_participants) { [
      participant1_with_discord,
      participant2_without_discord,
    ] }
    let(:program2_participants) { [
      participant3_with_discord,
    ] }
    let(:sf_client) { instance_double(SalesforceAPI,
      get_current_and_future_accelerator_programs: programs['records'],
      update_participant: nil,
      get_contact_info: nil,
    ) }
    let(:invite_code) { 'test-code' }

    before :each do
      allow(sf_client).to receive(:get_program_info)
        .with(program1_with_discord['Id'])
        .and_return(program1_with_discord)
      allow(sf_client).to receive(:get_program_info)
        .with(program2_without_discord['Id'])
        .and_return(program2_without_discord)
      allow(sf_client).to receive(:find_participants_by)
        .with(program_id: program1_with_discord['Id'])
        .and_return(program1_participants)
      allow(sf_client).to receive(:find_participants_by)
        .with(program_id: program2_without_discord['Id'])
        .and_return(program2_participants)
      allow(sf_client).to receive(:get_participant_id)
        .with(participant1_with_discord.program_id, participant1_with_discord.contact_id)
        .and_return(participant1_with_discord.id)
      allow(sf_client).to receive(:get_participant_id)
        .with(participant2_without_discord.program_id, participant2_without_discord.contact_id)
        .and_return(participant2_without_discord.id)
      allow(sf_client).to receive(:get_participant_id)
        .with(participant1_with_discord.program_id, contact1_with_discord['Id'])
        .and_return(participant1_with_discord.id)
      allow(sf_client).to receive(:get_contact_info)
        .with(contact1_with_discord['Id'])
        .and_return(contact1_with_discord)
      allow(sf_client).to receive(:get_contact_info)
        .with(contact2_without_discord['Id'])
        .and_return(contact2_without_discord)
      allow(SalesforceAPI).to receive(:client).and_return(sf_client)

      allow(bot).to receive(:create_invite).and_return(invite_code)
      allow(bot).to receive(:get_member)
      bot.instance_variable_set(:@servers, {server.id => server})
      allow(DiscordBot).to receive(:configure_member_from_records)
    end

    it 'creates invites for participants with no invite' do
      expect(bot).to receive(:create_invite)
        .once
      subject
    end

    it 'uses the server id for the participant\'s program to create invites' do
      expect(bot).to receive(:create_invite)
        .with(program1_with_discord['Discord_Server_ID__c'].to_i)
      subject
    end

    it 'updates participant after creating invite' do
      expect(sf_client).to receive(:update_participant)
        .with(participant2_without_discord.id, {'Discord_Invite_Code__c': invite_code})
        .once
      subject
    end

    it 'does not create invites for participants that have one' do
      expect(sf_client).not_to receive(:update_participant)
        .with(participant1_with_discord.id, anything)
      subject
    end

    it 'skips programs with no discord server id' do
      expect(sf_client).to receive(:find_participants_by)
        .with(program_id: program1_with_discord['Id'])
      expect(sf_client).not_to receive(:find_participants_by)
        .with(program_id: program2_without_discord['Id'])
      subject
    end

    it 'configures member for contacts with discord user id' do
      allow(participant1_with_discord).to receive(:contact_id).and_return(contact1_with_discord['Id'])
      allow(bot).to receive(:get_member).and_return(member)
      expect(DiscordBot).to receive(:configure_member_from_records).once
      subject
    end

    it 'does not delete invite after configuring member' do
      # just because someone has a member in the server, doesn't mean
      # they can actually access that account. don't needlessly expire
      # invites during sync; they may be new ones created by staff to allow
      # the person to sign up again.
      allow(participant1_with_discord).to receive(:contact_id).and_return(contact1_with_discord['Id'])
      allow(bot).to receive(:get_member).and_return(member)
      expect(DiscordBot).to receive(:configure_member_from_records).once
      expect(invite).not_to receive(:delete)
      subject
    end

    it 'does not configure member for contacts with no discord user id' do
      allow(sf_client).to receive(:find_participants_by).and_return([participant2_without_discord])
      expect(bot).not_to receive(:get_member)
      expect(DiscordBot).not_to receive(:configure_member_from_records)
      subject
    end

    context 'with dropped participant' do

      before :each do
        participant1_with_discord.status = SalesforceAPI::DROPPED
      end

      it 'deletes invite code if applicable' do
        expect(invite).to receive(:delete).once
        subject
      end

      it 'kicks member if applicable' do
        allow(bot).to receive(:get_member).and_return(member)
        expect(member).to receive(:kick).once
        subject
      end

      it 'does not kick member if no member found' do
        allow(bot).to receive(:get_member).and_return(nil)
        expect(member).not_to receive(:kick)
        subject
      end

      it 'updates participant record' do
        expect(sf_client).to receive(:update_participant)
          .with(participant1_with_discord.id, {'Discord_Invite_Code__c': nil})
          .once
        subject
      end
    end
  end

  # Bot command parsing
  describe '.process_admin_command' do
    subject { bot.process_admin_command(event) }

    let(:roles) { [ instance_double(Discordrb::Role, name: ADMIN_ROLES.first) ] }
    let(:server) { instance_double(Discordrb::Server, id: 'fake-server-id') }
    let(:user) { instance_double(Discordrb::User, id: 'fake-user-id', username: 'fake-username', discriminator: 1234) }
    let(:member) { instance_double(Discordrb::Member, id: 'fake-member-id', roles: roles) }
    let(:message) { instance_double(Discordrb::Message, content: message_content, author: member, respond: nil) }
    let(:event) { instance_double(Discordrb::Events::MessageEvent, server: server, author: member, message: message) }
    let(:message_content) { "#{BOT_COMMAND_KEY}test" }

    before :each do
      member.instance_variable_set(:@user, user)
    end

    context 'with sync_salesforce command' do
      let(:message_content) { "#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:sync_salesforce]}" }

      it 'calls the appropriate command function' do
        expect(bot).to receive(:sync_salesforce_command).with(event).once
        subject
      end
    end

    context 'with configure_member command' do
      let(:message_content) { "#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:configure_member]}" }

      it 'calls the appropriate command function' do
        expect(bot).to receive(:configure_member_command).with(event).once
        subject
      end
    end

    context 'with list_misconfigured command' do
      let(:message_content) { "#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:list_misconfigured]}" }

      it 'calls the appropriate command function' do
        expect(bot).to receive(:list_misconfigured_command).with(event).once
        subject
      end
    end

    context 'with create_invite command' do
      let(:message_content) { "#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:create_invite]}" }

      it 'calls the appropriate command function' do
        expect(bot).to receive(:create_invite_command).with(event).once
        subject
      end
    end

    context 'with unknown command' do
      it 'responds with the unknown command message' do
        expect(message).to receive(:respond).once
        expect(message).not_to receive(:edit)
        subject
      end
    end

    context 'with exception during command processing' do
      let(:message_content) { "#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:sync_salesforce]}" }

      before :each do
        allow(bot).to receive(:sync_salesforce_command).and_raise(StandardError.new('test'))
      end

      it 'sends a pretty error message' do
        expect(message).to receive(:respond).once
        expect {
          subject
        }.to raise_error(StandardError)
      end

      it 'lets the error propogate' do
        expect {
          subject
        }.to raise_error(StandardError)
      end
    end
  end

  describe '.alert_on_unconfigured_members' do
    subject { bot.alert_on_unconfigured_members }

    let(:unconfigured_members) { {} }

    before :each do
      allow(bot).to receive(:get_unconfigured_members).and_return(unconfigured_members)
      allow(Honeycomb).to receive(:add_field)
    end

    context 'with unconfigured members' do
      let(:unconfigured_members) { {
        # server_id => Array<Member>
        12 => [instance_double(Discordrb::Member, id: 34, display_name: '56')],
      } }

      it 'sends an alert' do
        expect(Honeycomb).to receive(:add_field).with('alert.unconfigured_members', true)
        subject
      end
    end

    context 'with no unconfigured members' do
      it 'does not send an alert' do
        expect(Honeycomb).not_to receive(:add_field).with('alert.unconfigured_members', true)
        subject
      end
    end
  end

  # Configure member
  describe 'self.configure_member' do
    subject { DiscordBot.configure_member(member, invite) }

    let(:server) { instance_double(Discordrb::Server, id: 'fake-server-id', name: 'fake-server-name') }
    let(:user) { instance_double(Discordrb::User, username: 'fake-username', discriminator: 1234) }
    let(:member) { instance_double(Discordrb::Member, id: 'fake-member-id', server: server, set_nick: nil, set_roles: nil, kick: nil, nick: nil, roles: []) }
    let(:invite) { instance_double(Discordrb::Invite, code: 'fake-invite-code', delete: nil) }
    let(:nickname) { 'test-nick' }
    let(:participant_role_name) { 'test-role1' }
    let(:cohort_schedule_role_name) { 'test-role2' }
    let(:cohort_role_name) { 'test-role3' }
    let(:participant_role) { instance_double(Discordrb::Role, name: participant_role_name) }
    let(:cohort_schedule_role) { instance_double(Discordrb::Role, name: cohort_schedule_role_name) }
    let(:cohort_role) { instance_double(Discordrb::Role, name: cohort_role_name) }
    let(:roles) { [participant_role, cohort_schedule_role, cohort_role] }
    let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant)) }
    let(:contact) { create(:salesforce_contact) }
    let(:sf_client) { instance_double(SalesforceAPI,
      get_participant_info_by: participant,
      get_contact_info: contact,
      update_contact: nil,
    ) }

    before :each do
      member.instance_variable_set(:@user, user)
      allow(SalesforceAPI).to receive(:client).and_return(sf_client)
      allow(DiscordBot).to receive(:compute_nickname).and_return(nickname)
      allow(DiscordBot).to receive(:compute_participant_role).and_return(participant_role_name)
      allow(DiscordBot).to receive(:compute_cohort_schedule_role).and_return(cohort_schedule_role_name)
      allow(DiscordBot).to receive(:compute_cohort_role).and_return(cohort_role_name)
      allow(DiscordBot).to receive(:get_role).with(server, participant_role_name).and_return(participant_role)
      allow(DiscordBot).to receive(:get_role).with(server, cohort_schedule_role_name).and_return(cohort_schedule_role)
      allow(DiscordBot).to receive(:get_or_create_cohort_role).and_return(cohort_role)
      allow(DiscordBot).to receive(:configure_cohort_channel)
    end

    context 'with participant that matches invite' do
      it 'updates contact with discord user id' do
        expect(sf_client).to receive(:update_contact)
          .with(participant.contact_id, {'Discord_User_ID__c': member.id})
          .once
        subject
      end

      it 'computes nickname' do
        expect(DiscordBot).to receive(:compute_nickname).once
        subject
      end

      it 'computes roles' do
        expect(DiscordBot).to receive(:compute_participant_role).once
        expect(DiscordBot).to receive(:compute_cohort_schedule_role).once
        expect(DiscordBot).to receive(:compute_cohort_role).once
        subject
      end

      it 'sets member nickname' do
        expect(member).to receive(:set_nick).with(nickname)
        subject
      end

      it 'sets member roles' do
        expect(member).to receive(:set_roles).with(roles)
        subject
      end

      it 'tries to delete invite' do
        expect(invite).to receive(:delete)
        subject
      end

      context 'with member nickname already set' do
        before :each do
          allow(member).to receive(:nick).and_return('test name')
        end

        it 'does not set nick again' do
          expect(member).not_to receive(:set_nick)
          subject
        end
      end

      context 'with no cohort role name' do
        let(:cohort_role_name) { nil }

        it 'does not create cohort role' do
          expect(DiscordBot).not_to receive(:get_or_create_cohort_role)
          subject
        end
      end
    end

    context 'with no participant that matches invite' do
      before :each do
        allow(sf_client).to receive(:get_participant_info_by).and_return(nil)
      end

      it 'exits early' do
        expect(sf_client).not_to receive(:get_contact_info)
        expect(sf_client).not_to receive(:update_contact)
        expect(DiscordBot).not_to receive(:compute_nickname)
        subject
      end
    end
  end

  # Bot commands
  describe '.sync_salesforce_command' do
    subject { bot.sync_salesforce_command(event) }

    let(:server_id) { '123' }
    let(:roles) { [ instance_double(Discordrb::Role, name: ADMIN_ROLES.first) ] }
    let(:server) { instance_double(Discordrb::Server, id: server_id) }
    let(:user) { instance_double(Discordrb::User, id: 'fake-user-id', username: 'fake-username', discriminator: 1234) }
    let(:member) { instance_double(Discordrb::Member, id: 'fake-member-id', roles: roles) }
    let(:message) { instance_double(Discordrb::Message, content: message_content, author: member, edit: nil) }
    let(:event) { instance_double(Discordrb::Events::MessageEvent, server: server, author: member, message: message) }
    let(:message_content) { "#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:sync_salesforce]} #{args}".strip }
    let(:programs) { create(:salesforce_current_and_future_programs, canvas_course_ids: [1, 2, 3]) }
    let(:program1_with_discord) { create(:salesforce_program_record, program_id: programs['records'][0]['Id'], discord_server_id: server_id) }
    let(:program2_without_discord) { create(:salesforce_program_record, program_id: programs['records'][1]['Id'], discord_server_id: nil) }
    let(:program3_with_discord) { create(:salesforce_program_record, program_id: programs['records'][2]['Id'], discord_server_id: server_id) }
    let(:sf_client) { instance_double(SalesforceAPI,
      get_current_and_future_accelerator_programs: programs['records'],
      update_program: nil,
      get_program_info: nil,
    ) }
    let(:args) { "" }

    before :each do
      allow(sf_client).to receive(:get_program_info)
        .with(program1_with_discord['Id'])
        .and_return(program1_with_discord)
      allow(sf_client).to receive(:get_program_info)
        .with(program2_without_discord['Id'])
        .and_return(program2_without_discord)
      allow(SalesforceAPI).to receive(:client).and_return(sf_client)
      allow(message).to receive(:respond).and_return(message)
      allow(bot).to receive(:sync_salesforce_program)
    end

    context 'with more than one program linked to the Discord server' do
      before :each do
        allow(sf_client).to receive(:get_current_and_future_accelerator_programs)
          .and_return([program1_with_discord, program3_with_discord])
      end

      it 'sends a message telling there is more than one program linked to the server and doesn\'t run rest of function' do
        expect(message).to receive(:respond)
        expect(sf_client).not_to receive(:update_program)
        subject
      end
    end

    context 'with no arguments' do
      context 'with already linked program' do
        # Any of the returned programs will do. We pick the first one just for convenience.
        let(:server_id) { programs['records'].first['Discord_Server_ID__c'] }
        let(:program_id) { programs['records'].first['Id'] }

        it 'responds' do
          expect(message).to receive(:respond)
          subject
        end

        it 'syncs linked program' do
          expect(bot).to receive(:sync_salesforce_program).with(program_id)
          subject
        end
      end

      context 'with no already linked program' do
        before :each do
          # Remove discord server IDs from all program records.
          programs['records'][0]['Discord_Server_ID__c'] = nil
          programs['records'][1]['Discord_Server_ID__c'] = nil
        end

        it 'responds' do
          expect(message).to receive(:respond)
          subject
        end

        it 'does not sync anything' do
          expect(bot).not_to receive(:sync_salesforce_program)
          subject
        end
      end
    end

    context 'with valid Salesforce Program ID argument, already linked' do
      let(:program_id) { program1_with_discord['Id'] }
      let(:args) { "#{program_id}" }

      it 'responds' do
        expect(message).to receive(:respond)
        subject
      end

      it 'does not update program' do
        expect(sf_client).not_to receive(:update_program)
        subject
      end

      it 'syncs program' do
        expect(bot).to receive(:sync_salesforce_program).with(program_id)
        subject
      end
    end

    context 'with valid Salesforce Program ID argument, not already linked' do
      let(:program_id) { program2_without_discord['Id'] }
      let(:args) { "#{program_id}" }

      context 'with no other programs linked to the same Discord server' do
        it 'responds' do
          expect(message).to receive(:respond)
          subject
        end

        it 'updates program' do
          expect(sf_client).to receive(:update_program)
            .with(program_id, {'Discord_Server_ID__c': server_id})
          subject
        end

        it 'syncs program' do
          expect(bot).to receive(:sync_salesforce_program).with(program_id)
          subject
        end
      end

      context 'with a different program already linked to the same Discord server' do
        before :each do
          allow(sf_client).to receive(:get_current_and_future_accelerator_programs)
          .and_return([program2_without_discord, program3_with_discord])
        end

        it 'sends a message telling there is already a program linked to the server' do
          expect(message).to receive(:respond)
          expect(sf_client).not_to receive(:update_program)
          expect(bot).not_to receive(:sync_salesforce_program)
          subject
        end
      end
    end

    context 'with invalid Salesforce Program ID argument' do
      let(:args) { "fake" }

      it 'responds' do
        expect(message).to receive(:respond)
        subject
      end

      it 'does not update program' do
        expect(sf_client).not_to receive(:update_program)
        subject
      end

      it 'does not sync program' do
        expect(bot).not_to receive(:sync_salesforce_program)
        subject
      end
    end

    context 'with too many arguments' do
      let(:args) { "one two three" }

      it 'responds' do
        expect(message).to receive(:respond)
        subject
      end

      it 'does not edit message' do
        expect(message).not_to receive(:edit)
        subject
      end

      it 'does not update program' do
        expect(sf_client).not_to receive(:update_program)
        subject
      end

      it 'does not sync program' do
        expect(bot).not_to receive(:sync_salesforce_program)
        subject
      end
    end
  end

  describe '.configure_member_command' do
    subject { bot.configure_member_command(event) }

    let(:server_id) { 123 }
    let(:roles) { [ instance_double(Discordrb::Role, name: ADMIN_ROLES.first) ] }
    let(:server) { instance_double(Discordrb::Server, id: server_id, members: [member], invites: invites) }
    let(:user) { instance_double(Discordrb::User, id: 'fake-user-id', username: 'fake-username', discriminator: 1234) }
    let(:member) { instance_double(Discordrb::Member, id: 'fake-member-id', roles: roles) }
    let(:message) { instance_double(Discordrb::Message, content: message_content, author: member, edit: nil, mentions: mentions) }
    let(:event) { instance_double(Discordrb::Events::MessageEvent, server: server, author: member, message: message) }
    let(:message_content) { "#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:configure_member]} #{args}".strip }
    let(:programs) { create(:salesforce_current_and_future_programs, canvas_course_ids: [1, 2]) }
    let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_fellow)) }
    let(:sf_client) { instance_double(SalesforceAPI,
      get_current_and_future_accelerator_programs: programs['records'],
      update_program: nil,
      get_program_info: nil,
      find_participant: nil,
      get_contact_info: nil,
      update_contact: nil,
    ) }
    let(:invites) { [] }
    let(:mentions) { [] }
    let(:args) { "" }

    before :each do
      allow(SalesforceAPI).to receive(:client).and_return(sf_client)
      allow(message).to receive(:respond).and_return(message)
      bot.instance_variable_set(:@servers, {server.id => server})
      allow(DiscordBot).to receive(:configure_member_from_records)
    end

    context 'with no arguments' do
      it 'responds' do
        expect(message).to receive(:respond)
        subject
      end

      it 'does not try to get programs' do
        expect(sf_client).not_to receive(:get_current_and_future_accelerator_programs)
        subject
      end
    end

    context 'with @mention' do
      # arbitrary user id
      let(:mentions) { [instance_double(Discordrb::User, id: 10)] }

      context 'with already linked program' do
        # doesn't matter which program
        let(:server_id) { programs['records'].first['Discord_Server_ID__c'] }

        context 'with valid contact id' do
          let(:args) { "@mention #{participant.contact_id}" }

          before :each do
            # doen't matter which program
            allow(sf_client).to receive(:find_participant)
              .with(contact_id: participant.contact_id, program_id: programs['records'].first['Id'])
              .and_return(participant)
          end

          it 'tries to get participant' do
            expect(sf_client).to receive(:find_participant)
            subject
          end

          it 'updates contact' do
            expect(sf_client).to receive(:update_contact)
            subject
          end

          it 'gets contact' do
            expect(sf_client).to receive(:get_contact_info)
            subject
          end

          it 'gets member' do
            expect(bot).to receive(:get_member).with(server_id, mentions.first.id)
            subject
          end

          it 'configures member' do
            expect(DiscordBot).to receive(:configure_member_from_records)
            subject
          end
        end

        context 'with invalid contact id' do
          let(:args) { "@mention test" }

          it 'tries to get participant' do
            expect(sf_client).to receive(:find_participant)
            subject
          end

          it 'exits before updating contact' do
            expect(sf_client).not_to receive(:update_contact)
            subject
          end
        end
      end

      context 'with no already linked program' do
        let(:args) { "@mention #{participant.contact_id}" }

        it 'responds' do
          expect(message).to receive(:respond)
          subject
        end

        it 'does not try to fetch participant' do
          expect(sf_client).not_to receive(:find_participant)
          subject
        end
      end
    end

    context 'with valid user id' do
      # arbitrary user id
      let(:target_user_id) { 23 }
      let(:target_member) { instance_double(Discordrb::Member, id: target_user_id) }
      let(:args) { "#{target_user_id} test" }
      # doesn't matter which program
      let(:server_id) { programs['records'].first['Discord_Server_ID__c'] }

      before :each do
        allow(bot).to receive(:get_member).and_return(target_member)
        allow(sf_client).to receive(:find_participant).and_return(participant)
      end

      it 'responds' do
        expect(message).to receive(:respond)
        subject
      end

      it 'gets member, twice' do
        expect(bot).to receive(:get_member)
          .exactly(2)
          .times
        subject
      end
    end

    context 'with invalid user id' do
      let(:args) { "test test" }

      before :each do
        allow(bot).to receive(:get_member).and_return(nil)
      end

      it 'responds' do
        expect(message).to receive(:respond)
        subject
      end

      it 'does not try to get programs' do
        expect(sf_client).not_to receive(:get_current_and_future_accelerator_programs)
        subject
      end
    end
  end

  describe '.list_misconfigured_command' do
    subject { bot.list_misconfigured_command(event) }

    # Note: even members with "no roles" always have the @everyone role.
    let(:no_roles) { [instance_double(Discordrb::Role, name: EVERYONE_ROLE)] }
    let(:member) { instance_double(Discordrb::Member, id: 'fake-member-id', roles: no_roles, display_name: nil) }
    let(:message) { instance_double(Discordrb::Message, content: message_content, edit: nil) }
    let(:message_content) { "#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:list_misconfigured]} #{args}".strip }
    let(:programs) { create(:salesforce_current_and_future_programs, canvas_course_ids: [1, 2]) }
    let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_fellow)) }
    let(:sf_client) { instance_double(SalesforceAPI,
      get_current_and_future_accelerator_programs: programs['records'],
      find_participants_by: [participant],
    ) }
    let(:args) { "" }
    # doesn't matter which program
    let(:server_id) { programs['records'].first['Discord_Server_ID__c'] }
    let(:server) { instance_double(Discordrb::Server, id: server_id, members: [member], invites: []) }
    let(:event) { instance_double(Discordrb::Events::MessageEvent, server: server, author: member, message: message) }

    before :each do
      allow(SalesforceAPI).to receive(:client).and_return(sf_client)
      allow(message).to receive(:respond).and_return(message)
    end

    it 'completes without error' do
      expect(message).to receive(:respond).once
      expect(message).to receive(:edit)
      expect {
        subject
      }.not_to raise_error
    end

  end

  describe '.create_invite_command' do
    subject { bot.create_invite_command(event) }

    let(:server_id) { 123 }
    let(:roles) { [ instance_double(Discordrb::Role, name: ADMIN_ROLES.first) ] }
    let(:server) { instance_double(Discordrb::Server, id: server_id, invites: invites) }
    let(:message) { instance_double(Discordrb::Message, content: message_content, edit: nil) }
    let(:event) { instance_double(Discordrb::Events::MessageEvent, server: server, message: message) }
    let(:invite) { instance_double(Discordrb::Invite, code: participant.discord_invite_code, delete: nil) }
    let(:message_content) { "#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:create_invite]} #{args}".strip }
    let(:programs) { create(:salesforce_current_and_future_programs, canvas_course_ids: [1, 2]) }
    let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_fellow)) }
    let(:sf_client) { instance_double(SalesforceAPI,
      get_current_and_future_accelerator_programs: programs['records'],
      find_participant: nil,
      update_participant: nil,
    ) }
    let(:invites) { [invite] }
    let(:args) { "" }

    before :each do
      allow(SalesforceAPI).to receive(:client).and_return(sf_client)
      allow(message).to receive(:respond).and_return(message)
      bot.instance_variable_set(:@servers, {server.id => server})
      allow(bot).to receive(:create_invite).and_return('fake code')
    end

    context 'with no arguments' do
      it 'responds' do
        expect(message).to receive(:respond)
        subject
      end

      it 'does not try to get programs' do
        expect(sf_client).not_to receive(:get_current_and_future_accelerator_programs)
        subject
      end
    end

    context 'with valid contact id argument' do
      let(:args) { "#{participant.contact_id}" }

      context 'with already linked program' do
        # doesn't matter which program
        let(:server_id) { programs['records'].first['Discord_Server_ID__c'].to_i }

        before :each do
          # doen't matter which program
          allow(sf_client).to receive(:find_participant)
            .with(contact_id: participant.contact_id, program_id: programs['records'].first['Id'])
            .and_return(participant)
        end

        it 'tries to get participant' do
          expect(sf_client).to receive(:find_participant)
          subject
        end

        it 'tries to delete existing invite' do
          expect(invite).to receive(:delete)
          subject
        end

        it 'creates a new invite' do
          expect(bot).to receive(:create_invite)
          subject
        end

        it 'updates participant record' do
          expect(sf_client).to receive(:update_participant)
          subject
        end
      end

      context 'with no linked program' do
        it 'responds' do
          expect(message).to receive(:respond)
          expect(message).to receive(:edit)
          subject
        end

        it 'does not try to get participant' do
          expect(sf_client).not_to receive(:find_participant)
          subject
        end
      end
    end
  end

  describe '.end_program_command' do
    subject { bot.end_program_command(event) }

    let(:retained_roles) { [ instance_double(Discordrb::Role, name: ADMIN_ROLES.first) ] }
    let(:non_retained_roles) { [ instance_double(Discordrb::Role, name: 'not a retained role') ] }
    let(:programs) { create(:salesforce_current_and_future_programs, canvas_course_ids: [1, 2]) }
    let(:program) { programs['records'].first }
    let(:server_id) { program['Discord_Server_ID__c'] }
    let(:server) { instance_double(Discordrb::Server, id: server_id, invites: invites, roles: roles, channels: channels, members: members) }
    let(:message) { instance_double(Discordrb::Message, content: message_content, edit: nil) }
    let(:event) { instance_double(Discordrb::Events::MessageEvent, server: server, message: message) }
    let(:invite) { instance_double(Discordrb::Invite, code: participant.discord_invite_code, delete: nil) }
    let(:message_content) { "#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:end_program]}" }
    let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_fellow)) }
    let(:sf_client) { instance_double(SalesforceAPI,
      get_current_and_future_accelerator_programs: programs['records'],
      find_participant: nil,
      update_participant: nil,
    ) }
    let(:retained_member) { instance_double(Discordrb::Member, roles: retained_roles, kick: nil) }
    let(:non_retained_member) { instance_double(Discordrb::Member, roles: non_retained_roles, kick: nil) }
    let(:members) { [retained_member, non_retained_member] }
    let(:invites) { [invite] }
    # channels
    let(:cohort_channel) { instance_double(Discordrb::Channel, name: 'cohort-test', delete: nil, type: TEXT_CHANNEL) }
    let(:cohort_template_channel) { instance_double(Discordrb::Channel, name: COHORT_TEMPLATE_CHANNEL, delete: nil, type: TEXT_CHANNEL) }
    let(:not_cohort_channel) { instance_double(Discordrb::Channel, name: 'test', delete: nil, type: TEXT_CHANNEL) }
    let(:general_channel) { instance_double(Discordrb::Channel, name: 'general', delete: nil, invites: invites, type: TEXT_CHANNEL) }
    let(:channels) { [cohort_channel, cohort_template_channel, not_cohort_channel] }
    # roles
    let(:cohort_role) { instance_double(Discordrb::Role, name: 'Cohort: Test', delete: nil) }
    let(:cohort_template_role) { instance_double(Discordrb::Role, name: COHORT_TEMPLATE_ROLE, delete: nil) }
    let(:not_cohort_role) { instance_double(Discordrb::Role, name: 'test', delete: nil) }
    let(:roles) { [cohort_role, cohort_template_role, not_cohort_role] }

    before :each do
      allow(sf_client).to receive(:find_participants_by).and_return([participant])
      allow(sf_client).to receive(:update_program)
      allow(SalesforceAPI).to receive(:client).and_return(sf_client)
      allow(message).to receive(:respond).and_return(message)
      bot.instance_variable_set(:@end_program_flag, {server.id => nil})
      bot.instance_variable_set(:@servers, {server.id => server})
      allow(bot).to receive(:create_invite).and_return('fake code')
      allow(bot).to receive(:sleep)
      allow(bot).to receive(:find_general_channel).and_return(general_channel)
      allow(DiscordBot).to receive(:cycle_channels)
    end

    context 'with initial run' do

      before :each do
        bot.instance_variable_set(:@end_program_flag, {server.id => nil})
      end

      it 'responds' do
        expect(message).to receive(:respond)
        subject
      end

      it 'sets flag' do
        # Hacky way to check if we're setting the instance variable before calling sleep.
        allow(bot).to receive(:sleep).and_raise(RuntimeError)
        expect {
          subject
        }.to raise_error(RuntimeError)
        expect(bot.instance_variable_get(:@end_program_flag)).to eq({server.id => true})
      end

      it 'sleeps' do
        subject
        expect(bot).to have_received(:sleep).with(COMMAND_CONFIRM_TIMEOUT)
      end

      it 'sets the flag back when its done' do
        expect(bot.instance_variable_get(:@end_program_flag)).to eq({server.id => nil})
      end

      it 'does not try to get programs' do
        expect(sf_client).not_to receive(:get_current_and_future_accelerator_programs)
        subject
      end
    end

    context 'with flag already set' do

      before :each do
        bot.instance_variable_set(:@end_program_flag, {server.id => true})
      end

      context 'with already linked program' do
        # doesn't matter which program
        let(:server_id) { programs['records'].first['Discord_Server_ID__c'].to_i }

        before :each do
#          # doen't matter which program
#          allow(sf_client).to receive(:find_participant)
#            .with(contact_id: participant.contact_id, program_id: program['Id'])
#            .and_return(participant)
        end

        it 'kicks non-retained members' do
          subject
          expect(non_retained_member).to have_received(:kick).once
        end

        it 'doesnt kick retained members' do
          subject
          expect(retained_member).not_to have_received(:kick)
        end

        it 'revokes all participant invites' do
          subject
          expect(invite).to have_received(:delete).once
        end

        it 'deletes cohort channels' do
          subject
          expect(cohort_channel).to have_received(:delete)
        end

        it 'doesnt delete the cohort template channel' do
          subject
          expect(cohort_template_channel).not_to have_received(:delete)
        end

        it 'doesnt delete non-cohort channels' do
          subject
          expect(not_cohort_channel).not_to have_received(:delete)
        end

        it 'deletes cohort roles' do
          subject
          expect(cohort_role).to have_received(:delete)
        end

        it 'doesnt delete the cohort template roles' do
          subject
          expect(cohort_template_role).not_to have_received(:delete)
        end

        it 'doesnt delete non-cohort roles' do
          subject
          expect(not_cohort_role).not_to have_received(:delete)
        end

        it 'calls cycle_channels' do
          subject
          expect(DiscordBot).to have_received(:cycle_channels).once
        end

        it 'resets the program discord server id' do
          subject
          expect(sf_client).to have_received(:update_program)
            .with(program['Id'], {'Discord_Server_ID__c': nil})
            .once
        end
      end
    end
  end


  # Create invite
  describe '.create_invite' do
    subject { bot.create_invite(server_id) }

    let(:server_id) { '11111' }  # arbitrary id
    let(:invite) { instance_double(Discordrb::Invite, code: 'test-code', uses: 0) }
    let(:channel) { instance_double(Discordrb::Channel, name: 'general', make_invite: invite) }

    it 'creates invite on #general channel' do
      expect(bot).to receive(:find_general_channel).and_return(channel)
      expect(channel).to receive(:make_invite).and_return(invite)
      subject
    end

    it 'updates @invites cache' do
      allow(bot).to receive(:find_general_channel).and_return(channel)
      allow(channel).to receive(:make_invite).and_return(invite)
      expect(bot.instance_variable_get(:@invites)).to eq({})
      subject
      expect(bot.instance_variable_get(:@invites)).to eq({server_id => {invite.code => invite.uses}})
    end
  end

  describe '.get_member' do
    subject { bot.get_member(server_id, user_id) }

    let(:server_id) { 1111 }  # arbitrary id
    let(:not_server_id) { 2222 }  # arbitrary id
    let(:user_id) { 33333 }  # arbitrary id
    let(:not_user_id) { 44444 }  # arbitrary id

    let(:member1) { instance_double(Discordrb::Member, id: user_id) }
    let(:not_member2) { instance_double(Discordrb::Member, id: not_user_id) }
    let(:server1) { instance_double(Discordrb::Server, id: server_id, members: [member1]) }
    let(:not_server2) { instance_double(Discordrb::Server, id: not_server_id, members: [not_member2]) }

    before :each do
      bot.instance_variable_set(:@servers, {
        server1.id => server1,
        not_server2.id => not_server2,
      })
    end

    it 'returns correct member' do
      expect(subject).to eq(member1)
    end
  end

  describe '.get_unconfigured_members' do
    subject { bot.get_unconfigured_members }

    let(:server_id) { 12 }
    let(:server) { instance_double(Discordrb::Server, id: server_id, members: members) }
    # Note: even members with "no roles" always have the @everyone role.
    let(:no_roles) { [instance_double(Discordrb::Role, name: EVERYONE_ROLE)] }
    let(:some_roles) { [instance_double(Discordrb::Role, name: FELLOW_ROLE)] + no_roles }
    let(:member1_with_roles) { instance_double(Discordrb::Member, display_name: 'member 1', roles: some_roles) }
    let(:member2_without_roles) { instance_double(Discordrb::Member, display_name: 'member 2', roles: no_roles) }
    let(:members) { [member1_with_roles, member2_without_roles] }

    before :each do
      bot.instance_variable_set(:@servers, {server_id => server})
    end

    it 'returns members with no roles (or only the @everyone role)' do
      expect(subject).to eq({
        server_id => [member2_without_roles],
      })
    end
  end

  # Compute from Participant
  describe 'self.compute_nickname' do
    subject { DiscordBot.compute_nickname(contact) }

    let(:contact) { create(:salesforce_contact) }

    it 'returns nickname' do
      expect(subject).to eq("#{contact['Preferred_First_Name__c']} #{contact['LastName']}")
    end
  end

  describe 'self.compute_participant_role' do
    subject { DiscordBot.compute_participant_role(participant) }

    context 'with Fellow' do
      let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_fellow)) }

      it 'returns role name' do
        expect(subject).to eq("Fellow")
      end
    end

    context 'with LC' do
      let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_lc)) }

      it 'returns role name' do
        expect(subject).to eq("Leadership Coach")
      end
    end

    context 'with TA' do
      let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_ta)) }

      it 'returns role name' do
        expect(subject).to eq("Teaching Assistant")
      end
    end

    context 'with CP' do
      let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_cp)) }

      it 'returns role name' do
        expect(subject).to eq("Coaching Partner")
      end
    end
  end

  describe 'self.compute_cohort_schedule_role' do
    subject { DiscordBot.compute_cohort_schedule_role(participant) }

    let(:cohort_schedule_day) { 'Monday' }

    context 'with Fellow' do
      let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_fellow, cohort_schedule_day: cohort_schedule_day)) }

      it 'returns role name' do
        expect(subject).to eq("Fellow: #{cohort_schedule_day} LL")
      end
    end

    context 'with LC' do
      let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_lc, cohort_schedule_day: cohort_schedule_day)) }

      it 'returns role name' do
        expect(subject).to eq("LC: #{cohort_schedule_day} LL")
      end
    end

    context 'with other role' do
      let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_ta, cohort_schedule_day: cohort_schedule_day)) }

      it 'returns nil' do
        expect(subject).to eq(nil)
      end
    end
  end

  describe 'self.compute_cohort_role' do
    subject { DiscordBot.compute_cohort_role(participant) }

    let(:cohort_schedule_day) { 'Monday' }
    let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_fellow, cohort_schedule_day: cohort_schedule_day)) }
    let(:cohort_lcs) { nil }
    let(:sf_client) { instance_double(SalesforceAPI,
      get_cohort_lcs: cohort_lcs,
    ) }

    before :each do
      allow(SalesforceAPI).to receive(:client).and_return(sf_client)
    end

    context 'with one LC' do
      let(:cohort_lcs) { [
        {'FirstName__c' => 'TestFirst', 'LastName__c' => 'TestLast'},
      ] }

      it 'returns role name' do
        expect(subject).to eq("Cohort: TestFirst TestLast #{cohort_schedule_day}")
      end
    end

    context 'with two LCs' do
      let(:cohort_lcs) { [
        {'FirstName__c' => 'TestFirst1', 'LastName__c' => 'TestLast1'},
        {'FirstName__c' => 'TestFirst2', 'LastName__c' => 'TestLast2'},
      ] }

      it 'returns role name' do
        # Note: Monday is hardcoded in the factory's CohortScheduleDayTime.
        expect(subject).to eq("Cohort: TestFirst1 TestFirst2 Monday")
      end
    end
  end

  # Roles/Channels
  describe 'self.get_or_create_cohort_role' do
    subject { DiscordBot.get_or_create_cohort_role(server, role_name) }

    let(:server) { instance_double(Discordrb::Server, id: 'fake-server-id', roles: roles, create_role: role) }
    let(:role_name) { 'test-role' }
    let(:role) { instance_double(Discordrb::Role, name: role_name) }
    let(:template_role) { instance_double(Discordrb::Role, name: 'Cohort: Template', permissions: nil) }
    let(:roles) { [template_role] }

    context 'with existing role' do
      let(:roles) { [role, template_role] }

      it 'returns role' do
        expect(subject).to eq(role)
      end

      it 'does not create role' do
        expect(server).not_to receive(:create_role)
        subject
      end
    end

    context 'with no existing role' do
      it 'creates role' do
        expect(server).to receive(:create_role).with(name: role_name, permissions: anything)
        subject
      end

      it 'returns role' do
        expect(subject).to eq(role)
      end
    end
  end

  describe 'self.configure_cohort_channel' do
    subject { DiscordBot.configure_cohort_channel(member, participant, role) }

    let(:role_name) { 'Cohort: Test Name' }
    let(:channel_name) { 'cohort-test-name' }
    let(:server) { instance_double(Discordrb::Server, id: 'fake-server-id', create_channel: channel, channels: channels, roles: roles) }
    let(:channel) { instance_double(Discordrb::Channel, name: channel_name, type: 0, :permission_overwrites= => nil, permission_overwrites: {}) }
    let(:overwrite) { instance_double(Discordrb::Overwrite, id: template_role.id, :type= => nil, :id= => nil, type: nil, to_hash: {}) }
    let(:lc_overwrite) { instance_double(Discordrb::Overwrite, id: lc_template_role.id, :type= => nil, :id= => nil, type: nil) }
    let(:template_channel) { instance_double(Discordrb::Channel, id: 1, name: 'cohort-template', type: 0, overwrites: {overwrite.id => overwrite, lc_overwrite.id => lc_overwrite}) }
    let(:category) { instance_double(Discordrb::Channel, name: 'Cohorts', type: 4) }
    let(:channels) { [template_channel] }
    let(:user) { instance_double(Discordrb::User, id: 'fake-user-id', username: 'fake-username', discriminator: 1234) }
    let(:member) { instance_double(Discordrb::Member, id: 'fake-member-id', server: server) }
    let(:role) { instance_double(Discordrb::Role, name: role_name, id: 'test-id-1') }
    let(:template_role) { instance_double(Discordrb::Role, name: 'Cohort: Template', id: 'test-id-2') }
    let(:lc_template_role) { instance_double(Discordrb::Role, name: 'Cohort: LC Template', id: 'test-id-3') }
    let(:roles) { [role, template_role, lc_template_role] }
    let(:participant) { }

    before :each do
      member.instance_variable_set(:@user, user)
      allow(Discordrb::Overwrite).to receive(:from_other).and_return(overwrite)
      allow(lc_overwrite).to receive(:dup).and_return(lc_overwrite)
    end

    context 'with Fellow' do
      let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_fellow)) }

      context 'with existing cohort channel' do
        let(:channels) { [channel, template_channel] }

        it 'does not create channel' do
          expect(server).not_to receive(:create_channel)
          subject
        end

        it 'does not change permission overwrites' do
          expect(channel).not_to receive(:permission_overwrites=)
          subject
        end
      end

      context 'with no existing cohort channel' do
        it 'creates cohort channel' do
          expect(server).to receive(:create_channel)
          subject
        end

        it 'updates permission overwrites' do
          expect(channel).to receive(:permission_overwrites=)
          subject
        end
      end
    end

    context 'with LC, with existing channel' do
      let(:channels) { [channel, template_channel] }
      let(:participant) { SalesforceAPI.participant_to_struct(create(:salesforce_participant_lc)) }

      it 'updates permission overwrites' do
        channels.each do |c|
          expect(c).to receive(:permission_overwrites).and_return([])
        end
        expect(channel).to receive(:permission_overwrites=)
        subject
      end

      it 'removes permission overwrites on old channels' do
        expect(DiscordBot).to receive(:remove_permission_overwrites)
          .with(member, except_channel_name: channel.name)
          .once
        subject
      end
    end
  end

  describe 'self.cycle_channels' do
    subject { DiscordBot.cycle_channels(server) }

    let(:server) { instance_double(Discordrb::Server) }

    context 'with some channels' do
      let(:retained_channel_1) { instance_double(Discordrb::Channel, name: 'rules', type: TEXT_CHANNEL, topic: nil, parent: nil, permission_overwrites: nil, delete: nil, :name= => nil ) }
      let(:retained_channel_2) { instance_double(Discordrb::Channel, name: 'bot-commands', type: TEXT_CHANNEL, topic: nil, parent: nil, permission_overwrites: nil, delete: nil, :name= => nil) }
      let(:cycled_channel_1) { instance_double(Discordrb::Channel, name: 'general', type: TEXT_CHANNEL, topic: nil, parent: nil, permission_overwrites: nil, delete: nil, :name= => nil) }
      let(:cycled_channel_2) { instance_double(Discordrb::Channel, name: 'monday-learning-lab', type: TEXT_CHANNEL, topic: nil, parent: nil, permission_overwrites: nil, delete: nil, :name= => nil) }
      let(:cycled_channel_3) { instance_double(Discordrb::Channel, name: 'teaching-assistants', type: TEXT_CHANNEL, topic: nil, parent: nil, permission_overwrites: nil, delete: nil, :name= => nil) }
      let(:retained_channels) { [retained_channel_1, retained_channel_2] }
      let(:cycled_channels) { [cycled_channel_1, cycled_channel_2, cycled_channel_3] }
      let(:channels) { retained_channels + cycled_channels }

      before :each do
        allow(server).to receive(:channels).and_return(channels)
        allow(server).to receive(:create_channel)
      end

      it 'doesnt cycle retained channels' do
        subject
        retained_channels.each do |retained_channel|
          expect(retained_channel).not_to have_received(:name=)
          expect(retained_channel).not_to have_received(:delete)
        end
      end

      it 'renames old channels' do
        subject
        cycled_channels.each do |cycled_channel|
          expect(cycled_channel).to have_received(:name=).once
        end
      end

      it 'creates new channels correctly' do
        subject
        cycled_channels.each do |cycled_channel|
          expect(server).to have_received(:create_channel).with(
            cycled_channel.name,
            TEXT_CHANNEL,
            topic: cycled_channel.topic,
            permission_overwrites: anything,
            parent: cycled_channel.parent,
          ).once
        end
      end

      it 'deletes old channels' do
        subject
        cycled_channels.each do |cycled_channel|
          expect(cycled_channel).to have_received(:delete).once
        end
      end

      it 'returns channel_count' do
        expect(subject).to eq(cycled_channels.count)
      end
    end
  end

  describe 'self.remove_permission_overwrites' do
    subject { DiscordBot.remove_permission_overwrites(member, except_channel_name: except_channel_name) }

    let(:except_channel_name) { 'skip-this-channel' }
    let(:member_id) { 'fake-member-id' }
    let(:member) { instance_double(Discordrb::Member, id: member_id, server: server) }
    let(:server) { instance_double(Discordrb::Server, id: 'fake-server-id', channels: channels) }
    let(:matching_overwrite) { instance_double(Discordrb::Overwrite, id: member_id, type: :member) }
    let(:not_matching_overwrite) { instance_double(Discordrb::Overwrite, id: 'not-member-id', type: :member) }
    let(:channel_with_matching_overwrite) { instance_double(Discordrb::Channel, name: 'test-channel-1', permission_overwrites: {
      matching_overwrite.id => matching_overwrite,
      not_matching_overwrite.id => not_matching_overwrite,
    }) }
    let(:except_channel) { instance_double(Discordrb::Channel, name: except_channel_name, permission_overwrites: {
      matching_overwrite.id => matching_overwrite,
      not_matching_overwrite.id => not_matching_overwrite,
    }) }
    let(:channels) { [channel_with_matching_overwrite, except_channel] }

    before :each do
      expect(DiscordBot).to receive(:get_overwrite_cohort_channels).and_return(channels)
      channels.each do |c|
        allow(c).to receive(:permission_overwrites=)
      end
    end

    it 'removes matching overwrites' do
      expect(channel_with_matching_overwrite).to receive(:permission_overwrites=).with({
        not_matching_overwrite.id => not_matching_overwrite,
      })
      subject
    end

    it 'skips the excluded channel' do
      expect(except_channel).not_to receive(:permission_overwrites=)
      subject
    end
  end

  describe 'self.get_overwrite_cohort_channels' do
    subject { DiscordBot.get_overwrite_cohort_channels(member) }

    let(:member_id) { 'fake-member-id' }
    let(:member) { instance_double(Discordrb::Member, id: member_id, server: server) }
    let(:server) { instance_double(Discordrb::Server, id: 'fake-server-id', channels: channels) }
    let(:matching_overwrite) { instance_double(Discordrb::Overwrite, id: member_id, type: :member) }
    let(:not_matching_overwrite) { instance_double(Discordrb::Overwrite, id: 'not-member-id', type: :member) }
    let(:cohort_channel_category) { instance_double(Discordrb::Channel, name: COHORT_CHANNEL_CATEGORY) }
    let(:not_cohort_channel_category) { instance_double(Discordrb::Channel, name: 'Test Category') }
    let(:channel_with_matching_overwrite) { instance_double(Discordrb::Channel, name: 'test-channel-1', parent: cohort_channel_category, permission_overwrites: {
      matching_overwrite.id => matching_overwrite,
      not_matching_overwrite.id => not_matching_overwrite,
    }) }
    let(:channel_without_matching_overwrite) { instance_double(Discordrb::Channel, name: 'test-channel-2', parent: cohort_channel_category, permission_overwrites: {
      not_matching_overwrite.id => not_matching_overwrite,
    }) }
    let(:channel_without_matching_parent) { instance_double(Discordrb::Channel, name: 'test-channel-3', parent: not_cohort_channel_category, permission_overwrites: {
      matching_overwrite.id => matching_overwrite,
      not_matching_overwrite.id => not_matching_overwrite,
    }) }
    let(:channels) { [] }

    context 'with channels with a matching overwrite and parent' do
      let(:channels) { [channel_with_matching_overwrite, channel_without_matching_overwrite, channel_without_matching_parent] }

      it 'returns channels with a matching overwrite and parent' do
        expect(subject).to eq([channel_with_matching_overwrite])
      end
    end

    context 'with no channels with a matching overwrite or parent' do
      let(:channels) { [channel_without_matching_overwrite, channel_without_matching_parent] }

      it 'returns an empty list' do
        expect(subject).to eq([])
      end
    end
  end

  describe 'self.delete_invite' do
    subject { DiscordBot.delete_invite(invite, reason) }

    let(:reason) { 'test reason' }
    let(:invite) { instance_double(Discordrb::Invite, delete: nil) }

    context 'with invite' do

      before :each do
        allow(invite).to receive(:delete).and_return(nil)
      end

      it 'deletes invite' do
        subject
        expect(invite).to have_received(:delete)
          .with(reason)
          .once
      end

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'with already deleted invite' do

      before :each do
        allow(invite).to receive(:delete).with(reason).and_raise(Discordrb::Errors::UnknownInvite)
      end

      it 'handles exception' do
        expect {
          subject
        }.not_to raise_error(Discordrb::Errors::UnknownInvite)
      end

      xit 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end

  describe 'self.kick_member' do
    subject { DiscordBot.kick_member(member, reason) }

    let(:reason) { 'test reason' }
    let(:member) { instance_double(Discordrb::Member, kick: nil) }

    context 'with member' do

      before :each do
        allow(member).to receive(:kick).and_return(nil)
      end

      it 'kicks member' do
        subject
        expect(member).to have_received(:kick)
          .with(reason)
          .once
      end

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'with already kicked member' do

      before :each do
        allow(member).to receive(:kick).with(reason).and_raise(Discordrb::Errors::UnknownMember)
      end

      it 'handles exception' do
        expect {
          subject
        }.not_to raise_error(Discordrb::Errors::UnknownMember)
      end

      xit 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end

  describe 'self.delete_channel' do
    subject { DiscordBot.delete_channel(channel, reason) }

    let(:reason) { 'test reason' }
    let(:channel) { instance_double(Discordrb::Channel, delete: nil) }

    context 'with channel' do

      before :each do
        allow(channel).to receive(:delete).and_return(nil)
      end

      it 'deletes channel' do
        subject
        expect(channel).to have_received(:delete)
          .with(reason)
          .once
      end

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'with already deleted channel' do

      before :each do
        allow(channel).to receive(:delete).with(reason).and_raise(Discordrb::Errors::UnknownChannel)
      end

      it 'handles exception' do
        expect {
          subject
        }.not_to raise_error(Discordrb::Errors::UnknownChannel)
      end

      xit 'returns false' do
        # TODO: why does this fail?
        expect(subject).to eq(false)
      end
    end
  end
end

# Disable bot at_exit handler in specs, to stop rspec from failing.
class DiscordBot
private
  def shut_down
  end
end