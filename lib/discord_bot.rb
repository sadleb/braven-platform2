require 'discordrb'
require 'honeycomb-beeline'
require 'sentry-ruby'

require 'salesforce_api'
require 'filter_logging'
require 'honeycomb_sentry_integration'

require_relative '../config/initializers/restclient_instrumentation'
require_relative '../config/initializers/honeycomb_sentry_integration'

# Development only - will be removed later.
SERVER_ID = ENV['BOT_SERVER_ID'].to_i

# Expiration (in seconds) for new invite codes.
# Max is 7 days, or 0 for infinity.
INVITE_MAX_AGE = 0

# Number of times an invite can be used (0 = infinite).
# Note: We delete invites once they are used successfully, and
# the Discord API counts invites as "used" even when someone starts
# to sign up but encounters an error, so it's safer to set this to 0.
INVITE_MAX_USES = 0

# Character(s) prepended to a message that make the bot treat it as a
# command.
# TODO: Refactor all the bot command stuff to use "slash commands" once
# Discordrb releases that functionality.
BOT_COMMAND_KEY = '!'
# Admin command strings.
ADMIN_COMMANDS = {
  sync_salesforce: 'sync_salesforce',
  configure_member: 'configure_member',
  list_misconfigured: 'list_misconfigured',
  create_invite: 'create_invite',
  end_program: 'end_program',
  stop: 'stop',
}
# Roles that are allowed to run admin commands.
ADMIN_ROLES = [
  'Admin',
  'Braven Staff',
]
# Roles that we don't want to kick out when a program ends.
RETAINED_ROLES = ADMIN_ROLES + [
  'Bot',
  # Below is the role assigned to our production bot by Discord, but we
  # shouldn't rely on it to remain unchanged. Always manually assign the
  # 'Bot' role above to the bot, as described in the Tech/Product Support
  # Discord Guide, so we have a fallback.
  'Braven Discord Integration',
]
# Other role names.
TA_ROLE = 'Teaching Assistant'
CP_ROLE = 'Coaching Partner'
LC_ROLE = 'Leadership Coach'
FELLOW_ROLE = 'Fellow'
EVERYONE_ROLE = '@everyone'

# Channel constants, for Discord API.
TEXT_CHANNEL = 0
CHANNEL_CATEGORY = 4

RETAINED_CHANNELS = [
  'rules',
  'admin-discord-news',
  'bot-commands',
]

# Stuff for dynamic cohort channels/roles.
COHORT_CHANNEL_CATEGORY = 'Cohorts'
COHORT_CHANNEL_DESCRIPTION = 'This channel is a space for communication and collaboration with your Accelerator Cohort.'
COHORT_TEMPLATE_CHANNEL = 'cohort-template'
COHORT_TEMPLATE_ROLE = 'Cohort: Template'
COHORT_TEMPLATE_LC_ROLE = 'Cohort: LC Template'
COHORT_CHANNEL_PREFIX = 'cohort-'
COHORT_ROLE_PREFIX = 'Cohort: '

# Other channel names.
GENERAL_CHANNEL = 'general'

# Other.
COMMAND_CONFIRM_TIMEOUT = 30

# Global logger.
LOGGER = Logger.new(STDOUT)

class DiscordBot
  def initialize(
    token: ENV['DISCORD_BOT_TOKEN'],
    log_level: ENV.fetch('LOG_LEVEL', 'DEBUG'),
    enabled: ENV['BOT_ENABLED'],
    sync_and_exit: false
  )
    LOGGER.level = log_level

    # We only want one instance of this bot running, so be sure
    # to unset this env var on all apps but one.
    unless enabled
      LOGGER.warn 'Quitting because BOT_ENABLED env var is unset'
      exit
    end

    initialize_monitoring

    # For use by scheduled task/CLI.
    @sync_and_exit = sync_and_exit

    # Note: If you want alllll the debug info, pass in `log_mode: :debug`.
    # Don't set log_mode to INFO or above in prod; it logs all channel messages.
    @bot = Discordrb::Bot.new(token: token, log_mode: :warn)

    # { server_id => Server }
    @servers = {}

    # { server_id => { invite_code => invite_uses } }
    @invites = {}

    # { server_id => Channel }
    @general_channels = {}

    # Per-server global flag for when the end_program admin command has been
    # started. Hash values will be true if someone started the command but
    # hasn't confirmed, and nil otherwise. We need this to be an instance
    # variable so that we can read/write it from different threads, each
    # running the end_program_command method.
    # Note: Ruby member variables aren't technically thread-safe:
    # https://bearmetal.eu/theden/how-do-i-know-whether-my-rails-app-is-thread-safe-or-not/
    # ...but for our purposes here, they're thread-safe-enough.
    # { server_id => boolean }
    @end_program_flag = {}

    # Start time set in ready event handler.
    @start_time = nil
  end

  def run
    # Event handler: The bot is fully connected to the websocket API.
    @bot.ready do |event|
      on_ready(event)
    end

    unless @sync_and_exit
      # Event handler: The bot was added to a new server.
      # We use a different server for each Region (or pilot program, etc)
      # because 1) it's how the course Slacks worked before, and 2) it simplifies
      # role/channel/permission management by one dimension.
      @bot.server_create do |event|
        on_server_create(event)
      end

      # Event handler: A message was received on any channel in any server.
      @bot.message do |event|
        on_message(event)
      end

      # Event handler: A new member was added to the server.
      @bot.member_join do |event|
        on_member_join(event)
      end
    end

    # Shut down gracefully if we get SIGTERM/SIGINT.
    at_exit do
      shut_down
    end

    # Run the bot (synchronous, blocks forever).
    @bot.run
  end

  #
  # Event Handlers
  #
  # When adding a new event handler, always follow the format:
  #
  #   def on_event_name(event)
  #     Honeycomb.start_span(name: 'bot.event_name') do
  #       <event handler code>
  #     end
  #   rescue StandardError => e
  #     record_error(e)
  #   end
  #
  # Event handlers are attached in the `run` function above like:
  #
  #   @bot.event_name do |event|
  #     on_event_name(event)
  #   end
  #
  # Each of these @bot.event_name blocks runs in its own thread, so if you're
  # modifying anything in member variables / local cache, be sure to do it in
  # a thread-safe way.
  #

  def on_ready(event)
    Honeycomb.start_span(name: 'bot.ready') do |span|
      Honeycomb.add_field('on_ready.sync_and_exit', @sync_and_exit)

      @start_time = DateTime.now.utc
      @servers = @bot.servers || {}
      Honeycomb.add_field('servers.count', @servers.count)
      Honeycomb.add_field('on_ready.server_ids', @servers.keys)
      LOGGER.info "Logged in from #{ENV['APPLICATION_HOST'] || 'unknown host'} at #{@start_time}"

      if @sync_and_exit
        sync_salesforce
        exit
      end

      init_invite_uses_cache
      alert_on_unconfigured_members
    end
  rescue StandardError => e
    record_error(e)
  end

  def on_server_create(event)
    Honeycomb.start_span(name: 'bot.server_create') do |span|
      LOGGER.debug "Joined new server #{event.server.id}"
      Honeycomb.add_field('server.id', event.server.id.to_s)
      Honeycomb.add_field('servers.count', @bot.servers.count)

      # Update local caches for the new server.
      @servers = @bot.servers || {}
      init_invite_uses_cache

      # Send a message to the #general channel asking for Admin permissions.
      send_to_general(
        event.server.id,
        "Please reorganize the bot role (as described in the Discord Guide setup instructions) to enable bot functionality."
      )
    end
  rescue StandardError => e
    record_error(e)
  end

  # A User is a unique Discord account. A Member is the unique join
  # of a specific User on a specific Server. In other words, we can have
  # two different Members on two different Servers, such that both Members
  # are tied to the same User. This also implies that a Member always
  # has a Server reference and a User reference.
  def on_member_join(event)
    Honeycomb.start_span(name: 'bot.member_join') do |span|
      server = event.server
      user = event.member.instance_variable_get(:@user)

      Honeycomb.add_field('user.username', user.username)
      Honeycomb.add_field('user.discriminator', user.discriminator)
      Honeycomb.add_field('member.id', event.member.id.to_s)
      Honeycomb.add_field('server.id', server.id.to_s)
      LOGGER.debug "Member join: '#{user.username}##{user.discriminator}' (#{event.member.id})"

      invite = find_used_invite(server)
      # If we couldn't figure out which invite they used, exit early.
      return unless invite

      # If we only found one used invite, we know it's correct, so configure the member.
      Honeycomb.add_field('invite.code', invite.code)
      # Note: This function may return on errors, so if you add more code after this call,
      # don't just assume it worked.
      DiscordBot.configure_member(event.member, invite)
    end
  rescue StandardError => e
    record_error(e)
  end

  def on_message(event)
    Honeycomb.start_span(name: 'bot.message') do |span|
      # Ignore all messages that don't look like a bot command.
      if event.message.content.start_with? BOT_COMMAND_KEY
        server = event.server
        Honeycomb.add_field('server.id', server.id.to_s)
        # event.author could be a Member or a User, but the ID will be the same
        # either way.
        Honeycomb.add_field('member.id', event.author.id.to_s)
        # Try to add the DN if this is a member.
        Honeycomb.add_field('member.display_name', event.author.display_name) if event.author.respond_to?(:display_name)

        if event.message.author.webhook? || event.message.author.roles.find { |r| ADMIN_ROLES.include? r.name }
          LOGGER.debug "Admin command"
          process_admin_command(event)
        else
          LOGGER.debug "Ignoring non-admin command"
        end
      end
    end
  rescue StandardError => e
    record_error(e)
  end

  #
  # Top-Level Utilities
  #
  # Functions called directly by one or more event handler.
  #

  # Initialize/update @invite cache for all servers.
  # See comments on find_used_invite for more info.
  def init_invite_uses_cache
    @servers.each do |server_id, server|
      @invites[server_id] ||= {}
      server.invites.each do |invite|
        @invites[server_id][invite.code] = invite.uses
      end
    end
  end

  # Finding which invite someone used is a little complicated, because the
  # Discord API doesn't give us this information directly. We have to look at
  # all invites in the server, and see which one(s) "uses" count have increased.
  # More info: https://anidiots.guide/coding-guides/tracking-used-invites.
  def find_used_invite(server)
    found_invite = nil
    server.invites.each do |invite|
      @invites[server.id] ||= {}
      @invites[server.id][invite.code] ||= 0
      if invite.uses > @invites[server.id][invite.code]
        # This invite has been used since the last time we checked.
        LOGGER.debug "Found used invite #{invite.code}"
        # Update the cache.
        @invites[server.id][invite.code] = invite.uses

        # If we found more than one used invite, alert and exit without configuring member.
        # See the linked article above for why we do this; in short, we can't tell what
        # Participant is linked to this Member if multiple Invites were used at the
        # same time.
        if found_invite
          LOGGER.warn "Multiple invites used, not sure who's who! Please fix members manually."
          Honeycomb.add_field('alert.multiple_invites_used', [found_invite.code, invite.code])
          # Force-refresh the cache, to make sure we're back up to speed with
          # current invite uses.
          init_invite_uses_cache
          return
        end

        found_invite = invite
      end
    end
    found_invite
  end

  # Fetch Programs/Participants/etc from Salesforce, and generate new
  # invite codes for Enrolled Participants who don't have one already.
  def sync_salesforce
    Honeycomb.start_span(name: 'bot.sync_salesforce') do |span|
      programs = SalesforceAPI.client.get_current_and_future_accelerator_programs
      program_ids = programs.map { |program| program['Id'] }
      Honeycomb.add_field('program_ids.count', program_ids.count)
      LOGGER.debug "Syncing #{program_ids.count} programs from Salesforce"

      program_ids.each do |program_id|
        sync_salesforce_program(program_id)
      end
      LOGGER.debug "Done syncing programs"
    end
  end

  # At this point, the message event is guaranteed to 1) have been sent by
  # a server admin/staff-level user, and 2) have started with the bot command
  # signifier BOT_COMMAND_KEY.
  def process_admin_command(event)
    case event.message.content
    when /^#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:sync_salesforce]}/
      LOGGER.debug "sync_salesforce command"
      Honeycomb.add_field('command', 'sync_salesforce')
      sync_salesforce_command(event)
    when /^#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:configure_member]}/
      LOGGER.debug "configure_member command"
      Honeycomb.add_field('command', 'configure_member')
      configure_member_command(event)
    when /^#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:list_misconfigured]}/
      LOGGER.debug "list_misconfigured command"
      Honeycomb.add_field('command', 'list_misconfigured')
      list_misconfigured_command(event)
    when /^#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:create_invite]}/
      LOGGER.debug "create_invite command"
      Honeycomb.add_field('command', 'create_invite')
      create_invite_command(event)
    when /^#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:end_program]}/
      LOGGER.debug "end_program command"
      Honeycomb.add_field('command', 'end_program')
      end_program_command(event)
    when /^#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:stop]}/
      LOGGER.debug "stop command"
      Honeycomb.add_field('command', 'stop')
      stop_command(event)
    else
      LOGGER.debug "unknown command"
      Honeycomb.add_field('command', 'unknown')
      event.message.respond "Unknown command. Try: #{ADMIN_COMMANDS.values.join(', ')}"
    end
  rescue StandardError => e
    # Simplify error handling for bot commands.
    message_content = "❌ Encountered an error!"
    message_content << "\n#{e.class.name}: #{e.message}"
    begin
      event.message.respond message_content
    rescue Discordrb::Errors::InvalidFormBody
      # Post a truncated response with an arbitrary max length, less than 4000.
      event.message.respond message_content.slice(0, 250)
    end
    raise e
  end

  # Alert on unconfigure members (members with no Roles).
  def alert_on_unconfigured_members
    servers_members = get_unconfigured_members
    servers_members.each do |server_id, members|
      LOGGER.warn("Unconfigured members on server #{server_id}: #{members.map {|m| m.display_name}}")
      Honeycomb.add_field('server.id', server_id.to_s)
      Honeycomb.add_field('alert.unconfigured_members', true)
      Honeycomb.add_field('alert.unconfigured_members.ids', members.map { |m| m.id.to_s })
      Honeycomb.add_field('alert.unconfigured_members.display_names', members.map { |m| m.display_name })
    end
  end

  # Given a Discord Member and an Invite, assign appropriate
  # Discord roles and an initial nickname for the Member on its server.
  # Note: May return on errors, so don't assume any call to this function was successful.
  def self.configure_member(member, invite)
    Honeycomb.start_span(name: 'bot.configure_member') do |span|
      server_id = member.server.id
      user = member.instance_variable_get(:@user)
      Honeycomb.add_field('server.id', server_id.to_s)
      Honeycomb.add_field('server.name', member.server&.name)
      Honeycomb.add_field('member.id', member.id.to_s)
      Honeycomb.add_field('invite.code', invite.code)
      Honeycomb.add_field('user.username', user&.username)
      Honeycomb.add_field('user.discriminator', user&.discriminator)

      # Try to map this invite to a Participant.
      # Always fetch latest info from SF, don't rely on a cache, so we're guaranteed to
      # have the latest name/role info at the time this runs.
      participant = SalesforceAPI.client.get_participant_info_by(discord_invite_code: invite.code)
      Honeycomb.add_field('participant.id', participant&.id)
      Honeycomb.add_field('contact.id', participant&.contact_id)
      # If no Participant was found, warn and exit without configuring member.
      if participant.nil?
        LOGGER.warn "Invite not assigned to any known Participant!"
        Honeycomb.add_field('alert.unknown_invite', invite.code)
        return
      end
      contact = SalesforceAPI.client.get_contact_info(participant.contact_id)

      # Save the Discord User ID to the SF Contact.
      # Note this overwrites the ID if there already was one in the Contact record.
      # This means e.g. if someone signs up for a second Program with a different Discord
      # account, we'll only keep the latest Discord User ID.
      begin
        LOGGER.debug "Found Participant, updating Contact record"
        SalesforceAPI.client.update_contact(participant.contact_id, {'Discord_User_ID__c': member.id})
      rescue RestClient::BadRequest => e
        LOGGER.warn "Attempted to reference same Discord user from multiple Contacts. Kicking the new user."
        record_error(e)
        LOGGER.warn "Probably a result of duplicate contacts, please fix the contacts."
        DiscordBot.kick_member(member, "Duplicate Contacts. Contact Support if you think this was a mistake.")
        return
      end

      # Configure nick and roles.
      DiscordBot.configure_member_from_records(member, participant, contact)

      # Once everything else is done, delete the invite, so it can't be used again.
      LOGGER.debug "Deleting invite"
      DiscordBot.delete_invite(invite, "Invite was used")
    end
  end

  #
  # Bot Commands
  #
  # Called by process_admin_command.
  # Always pass in a Discordrb::MessageEvent.
  #

  # Usage:
  #
  # 1) Sync this Server with a Program that already has this Server's
  # ID set up in Salesforce:
  #
  #   sync_salesforce
  #
  # 2) Set up a new Salesforce Program to use this Server, and sync:
  #
  #   sync_salesforce SF_PROGRAM_ID
  def sync_salesforce_command(event)
    server = event.server
    command = event.message.content.split
    args = command.drop(1)
    Honeycomb.add_field('sync_salesforce_command.args.count', args.count)
    Honeycomb.add_field('sync_salesforce_command.args', args)

    if args.count > 1
      # Wrong arguments.
      event.message.respond "Too many arguments, not sure what to do." \
        "\nTry `#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:sync_salesforce]} MY_SALESFORCE_PROGRAM_ID`"
      return
    elsif args.count == 1
      # Sync with the given Program.
      program_id = args.first
      message_content = "Starting sync with Program #{program_id}..."
      message = event.message.respond message_content

      program_info = SalesforceAPI.client.get_program_info(program_id)
      if program_info.nil?
        message_content << "\n❌ Program not found on Salesforce. Check the ID and try again?"
        message.edit(message_content)
        return
      end

      program_server_id = program_info['Discord_Server_ID__c'].to_i
      # Note: nil.to_i == 0
      if program_server_id == 0
        # We're setting up a new Program for the first time.
        message_content << "\n✅ Found Program in Salesforce..."
        message.edit(message_content)
        # Save this Server's ID to the Program record.
        SalesforceAPI.client.update_program(program_id, {'Discord_Server_ID__c': server.id})
        message_content << "\n✅ Updated Program to use this Discord server..."
        message.edit(message_content)
        sync_salesforce_program(program_id)
        message_content << "\n✅ Synced Program."
        message_content << "\nAll done!"
        message.edit(message_content)
      elsif program_server_id == server.id.to_i
        # This Server is already linked to this Program.
        message_content << "\n✅ Found Program in Salesforce..."
        message_content << "\n✅ Program is already linked to this Discord server..."
        message.edit(message_content)
        sync_salesforce_program(program_id)
        message_content << "\n✅ Synced Program."
        message_content << "\nAll done!"
        message.edit(message_content)
      else
        # This Server is already linked to a different Program.
        message_content << "\n⚠️ That Program was linked to a different Discord server! (ID: `#{program_server_id}`)"
        SalesforceAPI.client.update_program(program_id, {'Discord_Server_ID__c': server.id})
        message_content << "\n⚠️ Updated Program to use this Discord server."
        message_content << "\nIf you did this by mistake, go run the same command in the other server to reset."
        message_content << "\nIf you meant to do this, run `#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:sync_salesforce]}` now"
        message_content << " to sync the program to this server."
        message.edit(message_content)
      end
    else
      # Sync with the saved Program for this Server.
      message_content = "Starting sync with pre-configured Program..."
      message = event.message.respond message_content

      # Look for a current/future Program with this Discord Server ID.
      programs = SalesforceAPI.client.get_current_and_future_accelerator_programs
      program = programs.find { |program| program['Discord_Server_ID__c'].to_i == server.id.to_i }

      if program.nil?
        message_content << "\n❌ No Program found for this Discord server."
        message_content << "\nTry this command again with the Program ID you want to link, like:"
        message_content << "\n`#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:sync_salesforce]} a2Y11000002HY5mEAX`"
        message.edit(message_content)
        return
      end

      # If we did find a program tied to this server, sync it.
      message_content << "\n✅ Found Program #{program['Id']} in Salesforce..."
      message.edit(message_content)
      sync_salesforce_program(program['Id'])
      message_content << "\n✅ Synced Program."
      message_content << "\nAll done!"
      message.edit(message_content)
    end
  end

  # Usage:
  #
  # Link a Salesforce Participant to a Discord User.
  #
  #   configure_member @username SALESFORCE_CONTACT_ID
  #
  # OR (if you're in a channel where the user isn't, and you can't @mention them)
  #
  #   configure_member DISCORD_USER_ID SALESFORCE_CONTACT_ID
  def configure_member_command(event)
    server = event.server
    command = event.message.content.split

    if event.message.mentions&.first
      # If someone was @mentioned, get their ID.
      user_id = event.message.mentions&.first&.id
    else
      # If the user was specified by ID instead, try to fetch the member,
      # so we can error out if the ID isn't valid.
      user_id = get_member(server.id, command[1])&.id
    end
    contact_id = command[2]
    LOGGER.debug "User: #{user_id}, Contact: #{contact_id}"

    # This field has a prefix to differentiate it from member.id,
    # which is the member that called this function.
    Honeycomb.add_field('configure_member.user.id', user_id.to_s)
    Honeycomb.add_field('contact.id', contact_id)

    # Respond with usage if we couldn't parse the command.
    if user_id.nil? || contact_id.nil? || command.count != 3
      event.message.respond "Couldn't understand your request." \
        "\nTry `#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:configure_member]} @username SALESFORCE_CONTACT_ID`"
        "\nOR `#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:configure_member]} DISCORD_USER_ID SALESFORCE_CONTACT_ID`"
      return
    end

    # Try fetching the Participant.
    message_content = "Starting configuration for Contact #{contact_id}..."
    message = event.message.respond(message_content)

    programs = SalesforceAPI.client.get_current_and_future_accelerator_programs
    program = programs.find { |program| program['Discord_Server_ID__c'].to_i == server.id.to_i }

    if program.nil?
      message_content << "\n❌ No Program found for this Discord server."
      message_content << "\nFirst, sync this server with a Salesforce Program ID, like:"
      message_content << "\n`#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:sync_salesforce]} a2Y11000002HY5mEAX`"
      message.edit(message_content)
      return
    end
    Honeycomb.add_field('program.id', program['Id'])

    # If we found a Program tied to this server, use that ID to fetch the Participant.
    participant = SalesforceAPI.client.find_participant(contact_id: contact_id, program_id: program['Id'])
    Honeycomb.add_field('participant.id', participant&.id)
    if participant.nil?
      message_content << "\n❌ No Participant found for Contact #{contact_id}, Program #{program['Id']}."
      message.edit(message_content)
      return
    end

    message_content << "\n✅ Found Participant #{participant.id} in Salesforce..."
    message.edit(message_content)

    # If we found a Participant, update the Contact's Discord User ID.
    SalesforceAPI.client.update_contact(participant.contact_id, {'Discord_User_ID__c': user_id})
    message_content << "\n✅ Set Discord User ID for Contact #{participant.contact_id}..."
    message.edit(message_content)

    # Configure nick and roles.
    contact = SalesforceAPI.client.get_contact_info(participant.contact_id)
    member = get_member(server.id, user_id)
    DiscordBot.configure_member_from_records(member, participant, contact)
    message_content << "\n✅ Configured nickname/roles in Discord..."
    message.edit(message_content)

    # Then delete their invite link, so no one else can use it.
    Honeycomb.add_field('invite.code', participant.discord_invite_code)
    if participant.discord_invite_code
      invite = server.invites.find { |i| i.code == participant.discord_invite_code }
      if invite
        DiscordBot.delete_invite(invite, "configure_member command called manually")
        message_content << "\n✅ Deleted Discord Invite Code for Participant #{participant.id}..."
        message.edit(message_content)
      end
    end

    message_content << "\nAll done!"
    message.edit(message_content)
  end

  # Usage:
  #
  # List members that may be un- or misconfigured, based on
  #
  # 1. Participants with an invite code that has >0 uses or has been deleted,
  # and no Contact.Discord_User_ID__c;
  # 2. Members with a Fellow or LC role that don't have a total of 3 roles
  # (Participant role, Cohort role, Cohort schedule role);
  # 3. Members with a CP or TA role that don't have a total of 1 role;
  # 4. Members with no roles.
  #
  #   list_misconfigured
  def list_misconfigured_command(event)
    server = event.server

    message_content = "Starting check for misconfigured members..."
    message = event.message.respond(message_content)

    # Figure out which program to use.
    programs = SalesforceAPI.client.get_current_and_future_accelerator_programs
    program = programs.find { |program| program['Discord_Server_ID__c'].to_i == server.id.to_i }

    if program.nil?
      message_content << "\n❌ No Program found for this Discord server."
      message_content << "\nFirst, sync this server with a Salesforce Program ID, like:"
      message_content << "\n`#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:sync_salesforce]} a2Y11000002HY5mEAX`"
      message.edit(message_content)
      return
    end
    Honeycomb.add_field('program.id', program['Id'])

    message_content << "\n✅ Found Program #{program['Id']}..."
    message.edit(message_content)

    # First, check Participants.
    participants = SalesforceAPI.client.find_participants_by(program_id: program['Id'])
    Honeycomb.add_field('participants.count', participants&.count)
    message_content << "\nℹ️ Checking #{participants.count} program participants..."
    message.edit(message_content)
    unmatched_participants = []
    uninvited_participants = 0
    participants.each do |participant|
      # 1. Participants with an invite code that has >0 uses or has been deleted,
      # and no Contact.Discord_User_ID__c;
      if participant.discord_invite_code && participant.discord_user_id.nil?
        invite = server.invites.find { |i| i.code == participant.discord_invite_code }
        if invite && invite.uses > 0
          unmatched_participants << participant
        elsif invite.nil?
          unmatched_participants << participant
        end
      elsif participant.discord_invite_code.nil?
        uninvited_participants += 1
      end
    end

    message_content << "\nℹ️ Found #{uninvited_participants} participants without an invite."
    message.edit(message_content)

    if unmatched_participants.any?
      message_content << "\n⚠️ Found #{unmatched_participants.count} participants with used"
      message_content << " or deleted invites but no Discord User ID in their contact record:"
      unmatched_participants.each do |participant|
        message_content << "\n  **Participant**: `#{participant.id}`"
        message_content << "\n  **Contact**: `#{participant.contact_id}`"
        message_content << "\n  **Name**: #{participant.first_name} #{participant.last_name}"
        message_content << "\n  **Discord invite code**: ||#{participant.discord_invite_code}||"
        message_content << "\n"
      end
      message.edit(message_content)
    else
      message_content << "\n✅ Didn't find any issues with participants."
      message.edit(message_content)
    end

    # Then, check Members.
    members = server.members
    message_content << "\nℹ️ Checking #{members.count} server members..."
    message.edit(message_content)
    Honeycomb.add_field('members.count', members.count)

    wrong_role_members = []
    no_role_members = []
    members.each do |member|
      # Note: roles.count is the number of expected roles, plus the @everyone role.
      roles = member.roles
      if (roles.any? { |r| r.name == FELLOW_ROLE } && roles.count != 4) ||
          (roles.any? { |r| r.name == LC_ROLE } && roles.count != 4) ||
          (roles.any? { |r| r.name == CP_ROLE } && roles.count != 2) ||
          (roles.any? { |r| r.name == TA_ROLE } && roles.count != 2)
        # 2. Members with a Fellow or LC role that don't have a total of 3 roles;
        # 3. Members with a CP or TA role that don't have a total of 1 role.
        wrong_role_members << member
      elsif roles.count == 1
        # 4. Members with no roles.
        no_role_members << member
      end
    end

    if wrong_role_members.any?
      message_content << "\n⚠️ Found #{wrong_role_members.count} members with wrong roles:"
      wrong_role_members.each do |member|
        message_content << "\n  **Discord User ID**: `#{member.id}`"
        message_content << "\n  **Display name**: `#{member.display_name}`"
        roles = member.roles
          .map { |role| role.name }
          .filter { |name| name != EVERYONE_ROLE }
          .join(', ')
        message_content << "\n  Roles: #{roles}"
        message_content << "\n"
      end
      message.edit(message_content)
    end

    if no_role_members.any?
      message_content << "\n⚠️ Found #{no_role_members.count} members with no roles:"
      no_role_members.each do |member|
        message_content << "\n  **Discord User ID**: `#{member.id}`"
        message_content << "\n  **Display name**: `#{member.display_name}`"
        message_content << "\n"
      end
      message.edit(message_content)
    end

    if wrong_role_members.empty? && no_role_members.empty?
      message_content << "\n✅ Didn't find any issues with members."
      message.edit(message_content)
    end

    message_content << "\nAll done!"
    message.edit(message_content)
  end

  # Usage:
  #
  # Create an invite for a Contact's Participant in this server's
  # Program. If the Participant already had an invite, makes sure
  # that invite is deleted from this server first.
  #
  #   create_invite SF_CONTACT_ID
  def create_invite_command(event)
    server = event.server
    command = event.message.content.split
    args = command.drop(1)
    contact_id = args.first

    if args.count != 1
      # Wrong arguments.
      event.message.respond "Wrong arguments, not sure what to do." \
        "\nTry `#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:create_invite]} SALESFORCE_CONTACT_ID`"
      return
    end

    message_content = "Creating a new invite..."
    message = event.message.respond(message_content)
    Honeycomb.add_field('contact.id', contact_id)

    # Figure out which program to use.
    programs = SalesforceAPI.client.get_current_and_future_accelerator_programs
    program = programs.find { |program| program['Discord_Server_ID__c'].to_i == server.id.to_i }

    if program.nil?
      message_content << "\n❌ No Program found for this Discord server."
      message_content << "\nFirst, sync this server with a Salesforce Program ID, like:"
      message_content << "\n`#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:sync_salesforce]} a2Y11000002HY5mEAX`"
      message.edit(message_content)
      return
    end
    Honeycomb.add_field('program.id', program['Id'])

    message_content << "\n✅ Found Program #{program['Id']}..."
    message.edit(message_content)

    # If we found a Program tied to this server, use that ID to fetch the Participant.
    participant = SalesforceAPI.client.find_participant(contact_id: contact_id, program_id: program['Id'])
    Honeycomb.add_field('participant.id', participant&.id)
    if participant.nil?
      message_content << "\n❌ No Participant found for Contact #{contact_id}, Program #{program['Id']}."
      message.edit(message_content)
      return
    end

    message_content << "\n✅ Found Participant #{participant.id} in Salesforce..."
    message.edit(message_content)

    # If we found a Participant, check its existing invite, and delete if needed.
    if participant.discord_invite_code
      invite = server.invites.find { |i| i.code == participant.discord_invite_code }
      if invite
        if DiscordBot.delete_invite(invite, "Replaced by create_invite command")
          message_content << "\nℹ️ Deleted existing invite ||#{invite.code}||."
          message.edit(message_content)
        else
          message_content << "\nℹ️ Old invite ||#{invite.code}|| not found on this server."
          message.edit(message_content)
        end
      else
        Honeycomb.add_field('create_invite.invite_deleted', false)
        message_content << "\nℹ️ Old invite ||#{participant.discord_invite_code}|| not found on this server."
        message.edit(message_content)
      end
    end

    # Create a new invite, and update the Participant record.
    LOGGER.debug "Creating new invite for participant #{participant.id}"
    invite_code = create_invite(server.id)
    Honeycomb.add_field('invite.code', invite_code)
    message_content << "\n✅ Created new invite ||#{invite_code}|| (||<https://discord.com/invite/#{invite_code}>||)..."
    message.edit(message_content)

    SalesforceAPI.client.update_participant(participant.id, {'Discord_Invite_Code__c': invite_code})
    message_content << "\n✅ Updated Participant #{participant.id} in Salesforce..."
    message_content << "\nAll done!"
    message.edit(message_content)
  end

  # Usage:
  #
  # End a program and get ready for a new program launch.
  # Clears out old channels/messages, kicks old users, etc.
  # This command can run in two states: initial mode (sets a global flag, then exits),
  # and confirmation mode (reads the global flag, and continues).
  #
  #   end_program
  def end_program_command(event)
    server = event.server

    # First, we want to make absolutely certain someone meant to run this command.
    # Check the global flag to see if this is the initial run of this command, or
    # a confirmation.
    if @end_program_flag[server.id].nil?
      Honeycomb.add_field('end_program_flag', false)
      message_content = "Starting end program..."
      message = event.message.respond(message_content)

      message_content << "\n⚠️ Are you sure?! This will delete all message content and kick all non-staff!"
      message_content << "\n⚠️ This is irreversible! Make sure you're in the correct Discord server."
      message_content << "\nType `!end_program` again to confirm. If you do nothing, this process will cancel in #{COMMAND_CONFIRM_TIMEOUT} seconds."
      message.edit(message_content)

      # Set the global flag to `true` for this server.
      @end_program_flag[server.id] = true

      # Give them a chance to confirm by running the command again.
      # If they run this command again before the sleep finishes, the flag
      # will still be `true`, and we'll skip this confirmation block.
      sleep COMMAND_CONFIRM_TIMEOUT

      # If they still haven't confirmed, the flag will still be true.
      if @end_program_flag[server.id]
        # Expire the global flag, so we're back in the initial state.
        @end_program_flag[server.id] = nil
        # And print out a "cancelled" message.
        event.message.respond("🚫 Cancelled program end.")
      end

      return
    end

    Honeycomb.add_field('end_program_flag', true)

    message_content = "✅ Confirmed program end! Looking up pre-configured Program..."
    message = event.message.respond(message_content)

    # Reset the global flag back to the initial state.
    @end_program_flag[server.id] = nil

    # Make sure we're actually tied to a Program.
    # Look for a current/future Program with this Discord Server ID.
    programs = SalesforceAPI.client.get_current_and_future_accelerator_programs
    program = programs.find { |program| program['Discord_Server_ID__c'].to_i == server.id.to_i }

    # If no program was found, print some help info and stop.
    if program.nil?
      message_content << "\n❌ No Program found for this Discord server."
      message_content << "\nRun `#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:sync_salesforce]}` with the Program ID you want to link, like:"
      message_content << "\n`#{BOT_COMMAND_KEY}#{ADMIN_COMMANDS[:sync_salesforce]} a2Y11000002HY5mEAX`"
      message.edit(message_content)
      return
    end

    # If we did find a program tied to this server, continue.
    Honeycomb.add_field('program.id', program['Id'])
    message_content << "\n✅ Found Program #{program['Id']} in Salesforce..."
    message.edit(message_content)

    #
    # Start the program-end process!
    #

    # Kick all server members that don't have an admin/staff role.
    kicked_count = 0
    # Use .dup so we're not modifying the members list in-place as we loop over it.
    server.members.dup.each do |member|
      # Skip if the member has any "retained" roles.
      next if (RETAINED_ROLES & member.roles.map { |r| r.name }).any?

      kicked_count += 1
      DiscordBot.kick_member(member, "Program end")
    end
    Honeycomb.add_field('end_program.kicked_members.count', kicked_count)
    message_content << "\n✅ Kicked #{kicked_count} non-staff members..."
    message.edit(message_content)

    # Revoke all invites tied to Salesforce Participants in this Program.
    participants = SalesforceAPI.client.find_participants_by(program_id: program['Id'])
    Honeycomb.add_field('participants.count', participants&.count)
    message_content << "\nℹ️ Checking #{participants&.count} program participants..."
    message.edit(message_content)

    revoked_count = 0
    participants.each do |participant|
      if participant.discord_invite_code
        invite = server.invites.find { |i| i.code == participant.discord_invite_code }
        if invite
          revoked_count += 1
          DiscordBot.delete_invite(invite, 'Program end')
        end
      end
    end
    Honeycomb.add_field('end_program.revoked_invites.count', kicked_count)
    message_content << "\n✅ Revoked #{revoked_count} invites..."
    message.edit(message_content)

    # Delete all cohort channels (but not the cohort-template channel!)
    channel_count = 0
    # Use .dup so we're not modifying the channels list in-place as we loop over it.
    server.channels.dup.each do |channel|
      next unless channel.name.start_with? COHORT_CHANNEL_PREFIX
      next if channel.name == COHORT_TEMPLATE_CHANNEL

      channel_count += 1
      DiscordBot.delete_channel(channel, 'Program end')
    end
    Honeycomb.add_field('end_program.deleted_cohort_channels.count', channel_count)
    message_content << "\n✅ Deleted #{channel_count} old cohort channels..."
    message.edit(message_content)

    # Delete all cohort roles (but not the cohort template roles!)
    role_count = 0
    # Use .dup so we're not modifying the roles list in-place as we loop over it.
    server.roles.dup.each do |role|
      next unless role.name.start_with? COHORT_ROLE_PREFIX
      next if [COHORT_TEMPLATE_ROLE, COHORT_TEMPLATE_LC_ROLE].include? role.name

      role_count += 1
      role.delete('Program end')
    end
    Honeycomb.add_field('end_program.deleted_cohort_roles.count', role_count)
    message_content << "\n✅ Deleted #{role_count} old cohort roles..."
    message.edit(message_content)

    # "Cycle" most of the other channels, to remove all their content but keep
    # their name/permissions intact.
    channel_count = DiscordBot.cycle_channels(server)
    Honeycomb.add_field('end_program.cycled_channels.count', channel_count)
    message_content << "\n✅ Cycled #{channel_count} old channels..."
    message.edit(message_content)

    # We no longer want to sync this server to this Program, so let's detach them.
    SalesforceAPI.client.update_program(program['Id'], {'Discord_Server_ID__c': nil})
    message_content << "\n✅ Removed this Discord server from the Program..."
    message_content << "\nAll done!"
    message.edit(message_content)
  end

  def stop_command(event)
    event.message.respond("Stopping the bot!")
    exit
  end

  #
  # Lower-level Utilities
  #
  # Helper functions used by top-level utilities, that contain enough logic that
  # we still want to be able to write specs for them.
  #

  def sync_salesforce_program(program_id)
    Honeycomb.start_span(name: 'bot.sync_salesforce_program') do |span|
      Honeycomb.add_field('program.id', program_id)
      # Fetch Discord server ID from the Program, skip if there isn't one.
      program_info = SalesforceAPI.client.get_program_info(program_id)
      server_id = program_info['Discord_Server_ID__c'].to_i
      Honeycomb.add_field('server.id', server_id.to_s)

      # Skip Programs that don't have a Discord Server ID.
      return if server_id == 0

      # Skip Programs that have a Discord Server ID for a server we're not
      # currently in, so deleting or kicking the bot out of one server doesn't
      # break every other program.
      unless @servers.has_key?(server_id)
        Honeycomb.add_field('sync_salesforce_program.not_in_server', true)
        LOGGER.warn "Skipping Program #{program_id} because we're not in server #{server_id}"
        return
      end

      LOGGER.debug "Processing program #{program_id}"

      participants = SalesforceAPI.client.find_participants_by(program_id: program_id)
      Honeycomb.add_field('participants.count', participants.count)
      LOGGER.debug "Syncing #{participants.count} participants for program #{program_id}"

      participants.each do |participant|
        sync_salesforce_participant(server_id, participant)
      end
    end
  end

  def sync_salesforce_participant(server_id, participant)
    Honeycomb.start_span(name: 'bot.sync_salesforce_participant') do |span|
      Honeycomb.add_field('contact.id', participant.contact_id)
      Honeycomb.add_field('participant.discord_invite_code', participant.discord_invite_code)
      Honeycomb.add_field('participant.id', participant.id)
      Honeycomb.add_field('participant.status', participant.status)
      LOGGER.debug "Processing participant"

      if participant.discord_invite_code
        # Fetch the existing code if there is one.
        LOGGER.debug "Found existing invite for participant #{participant.id}"
        invite_code = participant.discord_invite_code

        if participant.status == SalesforceAPI::DROPPED
          # Revoke their invite.
          LOGGER.debug "Revoking dropped participant's invite"

          invite = @servers[server_id]&.invites&.find { |i| i.code == participant.discord_invite_code }
          if invite
            DiscordBot.delete_invite(invite, "Participant record was marked as Dropped.")
          end

          # Remove the discord code from their Participant record too, so if
          # they're re-enrolled later, the sync will make them a new invite.
          LOGGER.debug "Removing invite code from participant in Salesforce"
          SalesforceAPI.client.update_participant(participant.id, {'Discord_Invite_Code__c': nil})
        end

        # If they already had a code, they may have already signed up too;
        # check their contact record for a Discord User ID.
        if participant.discord_user_id
          user_id = participant.discord_user_id
          # They have already signed up; reassign roles, in case cohort mapping
          # happened after they signed up and they don't have cohort roles yet.
          # This also runs if people change cohorts, and will update their roles
          # appropriately.
          LOGGER.debug "Found Discord User ID, re-configuring in case roles changed"
          Honeycomb.add_field('member.id', user_id.to_s)

          member = get_member(server_id, user_id)
          if member
            if participant.status == SalesforceAPI::DROPPED
              # Kick them out.
              LOGGER.debug "Kicking dropped participant"

              DiscordBot.kick_member(member, "Participant record was marked as Dropped.")

              Honeycomb.add_field('sync_salesforce_participant.kicked_user', true)

              # Exit early.
              return
            end

            contact = SalesforceAPI.client.get_contact_info(participant.contact_id)
            DiscordBot.configure_member_from_records(member, participant, contact)
          end
        end
      elsif participant.status != SalesforceAPI::DROPPED
        # If there's no invite, and the Participant isn't dropped, create a new
        # invite and save it to the Participant record.
        LOGGER.debug "Creating new invite for participant #{participant.id}"
        invite_code = create_invite(server_id)
        SalesforceAPI.client.update_participant(participant.id, {'Discord_Invite_Code__c': invite_code})
      else
        LOGGER.debug "Not creating invite for Dropped participant #{participant.id}"
      end

      Honeycomb.add_field('invite.code', invite_code)
    end
  end

  # Note this function should only be called when a Contact already has
  # its Discord_User_ID__c set.
  def self.configure_member_from_records(member, participant, contact)
    user = member.instance_variable_get(:@user)
    LOGGER.debug "Forming nick and roles"

    # From the Salesforce data, figure out what nickname to use, and
    # what roles to assign. Three types of roles:
    # * participant_role: {Fellow, Leadership Coach, etc}
    # * cohort_schedule_role: {LC: Thursday LL, Fellow: Monday LL, etc}
    # * cohort_role: {Cohort: Susan Thursday, etc}
    nick = DiscordBot.compute_nickname(contact)
    Honeycomb.add_field('member.nick', nick)

    participant_role_name = DiscordBot.compute_participant_role(participant)
    cohort_schedule_role_name = DiscordBot.compute_cohort_schedule_role(participant)
    cohort_role_name = DiscordBot.compute_cohort_role(participant)

    role_names = [participant_role_name, cohort_schedule_role_name, cohort_role_name]
    LOGGER.debug "Member config: '#{user.username}##{user.discriminator}', nick: '#{nick}', roles: #{role_names}"
    Honeycomb.add_field('role_names', role_names)

    # If the member already has the correct cohort role, that implies all the other
    # roles and nick are also correct. Check their roles and exit early if we don't
    # need to change anything.
    return if member.roles.find { |r| r.name == cohort_role_name }

    # Fetch the Role objects from the Discord server, so we can add them to this user.
    roles = []

    # All but the Cohort roles are already created in the server.
    [participant_role_name, cohort_schedule_role_name].compact.each do |role_name|
      roles << DiscordBot.get_role(member.server, role_name)
    end

    # Cohort roles and channels may already exist, or we may have to create them.
    if cohort_role_name
      cohort_role = DiscordBot.get_or_create_cohort_role(member.server, cohort_role_name)
      if cohort_role
        roles << cohort_role
        DiscordBot.configure_cohort_channel(member, participant, cohort_role)
      end
    end

    # Ignore missing roles.
    # This just means the participant didn't have a cohort schedule and/or
    # cohort assigned to them on Salesforce yet.
    roles.compact!
    Honeycomb.add_field('roles.count', roles.count)
    LOGGER.debug "Assigning #{roles.count} roles"

    # Note this will remove any manually-added roles.
    # We do this so if someone changes cohorts, they will be removed from the
    # old cohort role and added to the new one.
    member.set_roles(roles)

    # Don't overwrite nicknames that have already been set.
    if member.nick.nil?
      member.set_nick(nick)
    end
  end

  # Generate a new invite for a given server, and update @invites.
  def create_invite(server_id)
    # Discord invites are attached to channels for some weird, probably legacy reason.
    # Always generate invites for the #general channel.
    general_channel = find_general_channel(server_id)
    Honeycomb.add_field('alert.nil_general_channel', true) if general_channel.nil?

    # Last parameters are: temporary=false, unique=true.
    invite = general_channel.make_invite(INVITE_MAX_AGE, INVITE_MAX_USES, false, true)
    @invites[server_id] ||= {}
    @invites[server_id][invite.code] = invite.uses

    invite.code
  end

  # Get Member object from a Server ID and User ID.
  # Note: User ID and Member ID always match.
  def get_member(server_id, user_id)
    server = @servers[server_id.to_i]
    return unless server

    server.members.find { |m| m.id.to_i == user_id.to_i }
  end

  # Get all unconfigured Members (members with no Roles) on all servers.
  # Returns a hash of { server_id => Array<Member> }.
  def get_unconfigured_members
    Honeycomb.start_span(name: 'bot.get_unconfigured_members') do |span|
      members = {}
      @servers.each do |server_id, server|
        LOGGER.debug "Checking server #{server.id} for unconfigured members"
        server.members.each do |member|
          LOGGER.debug "Checking roles for '#{member.display_name}'"
          if member.roles.filter { |r| r.name != EVERYONE_ROLE }.empty?
            members[server_id] ||= []
            members[server_id] << member
          end
        end
      end

      members
    end
  end

  def self.compute_nickname(contact)
    # Note: Nickname must be <= 32 characters.
    nick = "#{contact['Preferred_First_Name__c']} #{contact['LastName']}"
    if nick.length > 32
      # Try just using the first name, and if that's still too long, truncate
      # to 32 characters. This probably won't happen outside of test users?
      nick = "#{contact['Preferred_First_Name__c']}".slice(0, 32)
    end
    nick
  end

  # Participant role name
  def self.compute_participant_role(participant)
    case participant.role
    when SalesforceAPI::FELLOW
      FELLOW_ROLE
    when SalesforceAPI::LEADERSHIP_COACH
      if SalesforceAPI.is_coach_partner?(participant)
        CP_ROLE
      else
        LC_ROLE
      end
    when SalesforceAPI::TEACHING_ASSISTANT
      TA_ROLE
    end
  end

  # Cohort Schedule role name
  def self.compute_cohort_schedule_role(participant)
    # 'Tuesday, 6pm' -> 'Tuesday'
    ll_day = (participant.cohort_schedule || '').split(',').first
    return unless ll_day

    # TODO: is there any way to move these interpolated strings to constants?
    if participant.role == SalesforceAPI::FELLOW
      "Fellow: #{ll_day} LL"
    elsif SalesforceAPI.is_lc?(participant)
      "LC: #{ll_day} LL"
    end
  end

  # Cohort role name
  def self.compute_cohort_role(participant)
    return unless participant.cohort

    # 'Tuesday, 6pm' -> 'Tuesday'
    ll_day = (participant.cohort_schedule || '').split(',').first

    cohort_lcs = SalesforceAPI.client.get_cohort_lcs(participant.cohort_id)
    if cohort_lcs.count == 1
      cohort_role_name = "Cohort: #{cohort_lcs.first['FirstName__c']} #{cohort_lcs.first['LastName__c']} #{ll_day}".strip
      return cohort_role_name
    elsif cohort_lcs.count > 1
      first_names = cohort_lcs.map { |lc| lc['FirstName__c'] }.join(' ')
      cohort_role_name = "Cohort: #{first_names} #{ll_day}".strip
      return cohort_role_name
    else
      LOGGER.warn "No LCs for Cohort '#{participant.cohort}'; cohort channels/roles will be missing!"
      return nil
    end
  end

  def self.get_role(server, role_name)
    Honeycomb.start_span(name: 'bot.get_role') do |span|
      Honeycomb.add_field('role.name', role_name)
      LOGGER.debug "Fetching role '#{role_name}'"

      server.roles.find { |r| r.name == role_name }
    end
  end

  # Given an Cohort role name, return a Discord role.
  # Create the roles on the fly if they do not already exist on the given server.
  def self.get_or_create_cohort_role(server, role_name)
    Honeycomb.start_span(name: 'bot.get_or_create_cohort_role') do |span|
      Honeycomb.add_field('role.name', role_name)
      LOGGER.debug "Fetching/creating role"

      # Fetch the role if it already exists.
      role = server.roles.find { |r| r.name == role_name }

      # Otherwise, try to create it.
      unless role
        template_role = server.roles.find { |r| r.name == COHORT_TEMPLATE_ROLE }
        role = server.create_role(name: role_name, permissions: template_role.permissions)
      end

      LOGGER.debug "Role fetched/created"

      role
    end
  end

  # Given an Array<Role>, ensure all appropriate private Cohort channels for those
  # roles have been created (creating new ones on the fly if they have not), and that
  # each role has been assigned access to its respective channel. Also gives additional
  # management permissions to LCs on their own private Cohort channels.
  # The end result for Fellows should look like:
  #   Cohort: My Cohort Name (read/write)-> #cohort-my-cohort-name
  # And for LCs:
  #   Cohort: My Cohort Name (read/write)-> #cohort-my-cohort-name
  #   My Discord User (read/write/manage)-> #cohort-my-cohort-name
  def self.configure_cohort_channel(member, participant, role)
    Honeycomb.start_span(name: 'bot.configure_cohort_channel') do |span|
      server = member.server

      Honeycomb.add_field('member.id', member.id.to_s)
      Honeycomb.add_field('server.id', server.id.to_s)
      Honeycomb.add_field('contact.id', participant.contact_id)
      Honeycomb.add_field('program.id', participant.program_id)
      Honeycomb.add_field('role.name', role.name)
      LOGGER.debug "Ensuring proper channel:role configuration for '#{role.name}' role."

      # Cohort channel name is based on the role name, downcased, with spaces replaced
      # with dashes and all other non-alphabetical characters stripped.
      # E.g. 'Cohort: Susan Thursday' -> '#cohort-susan-thursday'
      channel_name = role.name
        .gsub(/ /, '-')
        .gsub(/[^\p{Alpha}-]/, '')
        .downcase

      # If the channel already exists, find it.
      channel = server.channels.find { |c| c.type == TEXT_CHANNEL && c.name == channel_name }

      # Default to not changing permission overwrites.
      permission_overwrites = {}

      # If the channel didn't exist, create it.
      unless channel
        LOGGER.debug "No existing Cohort channel found; creating one"
        # Cohort channels go in the 'Cohorts' channel category on the server.
        category = server.channels.find { |c| c.type == CHANNEL_CATEGORY && c.name == COHORT_CHANNEL_CATEGORY }
        channel = server.create_channel(
          channel_name,
          TEXT_CHANNEL,  # channel type
          topic: COHORT_CHANNEL_DESCRIPTION,
          # Note: We don't set permission_overwrites, so the new channel will
          # inherit the permissions of its category parent (Cohorts).
          parent: category,
        )

        # Add an overwrite to give this role access to this channel.
        # This is a lot of steps, but we're just copying the permissions from the
        # "Cohort: Template" role and "#cohort-template" channel to the new role/channel.
        LOGGER.debug "Adding channel:role permission overwrite for '#{channel.name}'"
        template_channel = server.channels.find { |c| c.type == TEXT_CHANNEL && c.name == COHORT_TEMPLATE_CHANNEL }
        Honeycomb.add_field('template_channel.id', template_channel&.id.to_s)
        template_role = server.roles.find { |r| r.name == COHORT_TEMPLATE_ROLE }
        Honeycomb.add_field('template_role.id', template_role&.id.to_s)
        template_overwrite = template_channel.overwrites[template_role.id]
        Honeycomb.add_field('template_overwrite.id', template_overwrite&.id.to_s)
        # Change the overwrite ID from the template role to the current role.
        template_overwrite.id = role.id
        permission_overwrites = channel.permission_overwrites
        permission_overwrites[template_overwrite.id] = Discordrb::Overwrite.from_other(template_overwrite)
      end

      # If this member is an LC, we also need an additional "permission overwrite" on
      # the private Cohort channel, to give them additional management permissions in
      # the channel. (We can't just have cohort-channel:LC-role permissions, because we
      # don't want LCs to have management permissions in all Cohort channels, only their own.)
      if SalesforceAPI.is_lc?(participant)
        # Remove any existing overwrites on other channels, in case the LC's cohort name has changed.
        LOGGER.debug "Checking/removing old cohort channel overwrites for LC"
        DiscordBot.remove_permission_overwrites(member, except_channel_name: channel.name)

        # Same as channel:role stuff above, we copy from a template permissions overwrite
        # to create a new channel:member permissions overwrite.
        LOGGER.debug "Adding channel:member permission overwrite, since participant is an LC"
        template_channel = server.channels.find { |c| c.type == TEXT_CHANNEL && c.name == COHORT_TEMPLATE_CHANNEL }
        Honeycomb.add_field('lc_template_channel.id', template_channel&.id.to_s)
        lc_template_role = server.roles.find { |r| r.name == COHORT_TEMPLATE_LC_ROLE }
        Honeycomb.add_field('lc_template_role.id', lc_template_role&.id.to_s)
        # MUST call .dup on this assignment, otherwise we end up modifying the
        # template channel's overwrites in the local cache, and break the stuff
        # in remove_permission_overwrites in subsequent calls.
        lc_template_overwrite = template_channel.overwrites[lc_template_role.id].dup
        Honeycomb.add_field('lc_template_overwrite.id', lc_template_overwrite&.id.to_s)
        # Change overwrite type from 'role' to 'member', since the template is a role but
        # we're creating a member-specific overwrite.
        lc_template_overwrite.type = :member
        # Change the overwrite ID from the template role to the current member.
        lc_template_overwrite.id = member.id
        permission_overwrites = channel.permission_overwrites if permission_overwrites.empty?
        permission_overwrites[lc_template_overwrite.id] = Discordrb::Overwrite.from_other(lc_template_overwrite)
      end

      channel.permission_overwrites = permission_overwrites unless permission_overwrites.empty?

      Honeycomb.add_field('permission_overwrites', permission_overwrites.map { |k, v| v.to_hash })
      Honeycomb.add_field('channel.name', channel.name)
      LOGGER.debug "Permissions assigned"
    end
  end

  # Clone/delete text channels to clear out their contents while retaining
  # their settings.
  def self.cycle_channels(server)
    channel_count = 0
    Honeycomb.start_span(name: 'bot.cycle_channels') do
      # Use .dup so we're not modifying the channels list in-place as we loop over it.
      server.channels.dup.each do |old_channel|
        LOGGER.debug "Found channel ##{old_channel.name}"
        # Skip everything but text channels.
        next unless old_channel.type == TEXT_CHANNEL
        # Some channels, like #rules, have special settings in Discord. We don't
        # want to delete those. Others, like #bot-commands, are just easier to
        # keep, and have no risk of exposing student PII because they're staff-only.
        next if RETAINED_CHANNELS.include? old_channel.name
        LOGGER.debug "Cycling ##{old_channel.name}"

        channel_count += 1

        # Rename the channel to *-old.
        channel_name = old_channel.name
        old_channel.name = "#{channel_name}-old"

        # Copy the old channel settings to create a new channel.
        server.create_channel(
          channel_name,
          TEXT_CHANNEL,
          topic: old_channel.topic,
          permission_overwrites: old_channel.permission_overwrites&.map { |k, v| Discordrb::Overwrite.from_other(v) },
          parent: old_channel.parent,
        )

        # Delete the old channel.
        DiscordBot.delete_channel(old_channel, 'Program end')
      end
    end
    channel_count
  end

  # Remove permission overwrites for a given member, everywhere except a given channel name.
  # This duplicates some of the logic from get_overwrite_channels, but it's easier to test
  # if we do get and remove in separate steps.
  def self.remove_permission_overwrites(member, except_channel_name: nil)
    LOGGER.debug "Removing permission overwrites for member in all channels"
    Honeycomb.start_span(name: 'bot.remove_permission_overwrites') do
      Honeycomb.add_field('member.id', member.id.to_s)
      Honeycomb.add_field('server.id', member.server.id.to_s)
      Honeycomb.add_field('remove_permission_overwrites.except_channel_name', except_channel_name)

      DiscordBot.get_overwrite_channels(member).each do |channel|
        next if channel.name == except_channel_name
        filtered_overwrites = channel.permission_overwrites.reject {
          |k, v| v.type == :member && v.id == member.id
        }
        channel.permission_overwrites = filtered_overwrites
      end
    end
  end

  # Get all channels where a given member has permission overwrites.
  def self.get_overwrite_channels(member)
    LOGGER.debug "Checking permission overwrites for member in all channels"
    Honeycomb.start_span(name: 'bot.get_overwrite_channels') do
      Honeycomb.add_field('member.id', member.id.to_s)
      Honeycomb.add_field('server.id', member.server.id.to_s)

      channels = []
      member.server.channels.each do |channel|
        channels << channel if channel.permission_overwrites.any? {
          |k, v| v.type == :member && v.id == member.id
        }
      end

      Honeycomb.add_field('permission_overwrite_channels.channel_names', channels.map { |c| c.name })
      Honeycomb.add_field('permission_overwrite_channels.count', channels.count)

      channels
    end
  end

  # Safe-delete methods that handle race conditions when multiple instances of
  # the bot are running at once.

  # Returns true if deleted, false otherwise.
  def self.delete_invite(invite, reason=nil)
    invite.delete(reason)
    Honeycomb.add_field('invite_deleted', true)
    return true
  rescue Discordrb::Errors::UnknownInvite
    # Probably another instance of the bot got to it first.
    LOGGER.debug "Invite already deleted"
    Honeycomb.add_field('invite_deleted', false)
    Honeycomb.add_field('invite_delete_failed', true)
    return false
  end

  # Returns true if deleted, false otherwise.
  def self.kick_member(member, reason=nil)
    member.kick(reason)
    return true
  rescue Discordrb::Errors::UnknownMember
    # Probably another instance of the bot got to it first.
    LOGGER.debug "Member already kicked"
    Honeycomb.add_field('member_kick_failed', true)
    return false
  end

  # Returns true if deleted, false otherwise.
  def self.delete_channel(channel, reason=nil)
    channel.delete(reason)
    return true
  rescue Discordrb::Errors::UnknownChannel
    # Probably another instance of the bot got to it first.
    LOGGER.debug "Channel already deleted"
    Honeycomb.add_field('channel_delete_failed', true)
    return false
  end

private

  #
  # Internals
  #
  # Things we don't need/want to write specs for, so they're safe to mark as `private`.
  #

  # Initialize Honeycomb and Sentry.
  def initialize_monitoring
    # Configure Honeycomb.
    Honeycomb.configure do |config|
      config.write_key = ENV['HONEYCOMB_WRITE_KEY']
      config.dataset = ENV['HONEYCOMB_BOT_DATASET']
      config.presend_hook do |fields|
        FilterLogging.filter_honeycomb_data(fields)

        # Fix restclient_instrumentation class name being incorrectly set for Discord API calls.
        if fields['name'].start_with?('restclient')
          if fields.has_key?('restclient.class_name') && fields['restclient.class_name'] == 'Api'
            fields['restclient.class_name'] = 'Discordrb::API'
          end
        end

        fields
      end
    end

    # Configure Sentry.
    Sentry.init do |config|
      config.dsn = ENV['SENTRY_BOT_DSN']

      # Turn off tracing, since we use Honeycomb for that.
      config.traces_sample_rate = 0.0

      config.before_send = lambda do |event, hint|
        FilterLogging.filter_sentry_data(event, hint)
      end
    end

  end

  # Log and send errors to Sentry.
  def record_error(e)
    LOGGER.error e.backtrace.join("\n\t")
      .sub("\n\t", ": #{e}#{e.class ? " (#{e.class})" : ''}\n\t")
    Sentry.capture_exception(e)
  end

  # Find the #general channel for a given server.
  # Attempts to find the channel in the cache first, otherwise looks it up
  # and caches it for the next time.
  def find_general_channel(server_id)
    Honeycomb.add_field('find_general_channel.server_ids', @servers.keys.to_s)
    Honeycomb.add_field('find_general_channel.bot_server_ids', @bot.servers.keys.to_s)
    Honeycomb.add_field('find_general_channel.server_id', server_id.to_s)
    Honeycomb.add_field('find_general_channel.servers_channels', @servers.transform_values { |s| s.channels.map { |c| [c.id, c.name, c.type] } }.to_s)
    Honeycomb.add_field('find_general_channel.bot_servers_channels', @bot.servers.transform_values { |s| s.channels.map { |c| [c.id, c.name, c.type] } }.to_s)
    Honeycomb.add_field('find_general_channel.general_channels', @general_channels.transform_values { |c| [c&.id, c&.name, c&.type] }.to_s)

    @general_channels[server_id] ||= @servers[server_id].channels.find { |channel|
      channel.name == GENERAL_CHANNEL && channel.type == TEXT_CHANNEL
    }
  end

  def send_to_general(server_id, msg)
    LOGGER.info msg
    general_channel = find_general_channel(server_id)
    general_channel.send_message(msg)
  end

  # Shutdown handler.
  def shut_down
    stop_time = DateTime.now.utc
    Honeycomb.start_span(name: 'bot.stop') do |span|
      Honeycomb.add_field('start_time', @start_time)
      Honeycomb.add_field('stop_time', stop_time)
      Honeycomb.add_field('uptime', stop_time - @start_time) if @start_time
    end
    LOGGER.info "Shutting down at #{stop_time}"
    @bot.stop
  end

end
