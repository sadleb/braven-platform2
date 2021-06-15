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

# Global logger.
LOGGER = Logger.new(STDOUT)

class DiscordBot

  def initialize(
    token: ENV['BOT_TOKEN'],
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

    # Start time set in ready event handler.
    @start_time = nil
  end

  def run
    # Event handler: The bot is fully connected to the websocket API.
    @bot.ready do |event|
      on_ready(event)
    end

    # Event handler: The bot was added to a new server.
    # We use a different server for each Region (or pilot program, etc)
    # because 1) it's how the course Slacks worked before, and 2) it simplifies
    # role/channel/permission management by one dimension.
    @bot.server_create do |event|
      on_server_create(event)
    end

    # Event handler: A message was received on any channel in any server.
    # TODO: Only allow Admins to run commands.
    # TODO: Add a !configure_member command to manually link a member to a Participant ID.
    # TODO: Add a !sync command to run salesforce_sync.
#    @bot.message do |event|
#      LOGGER.debug event.message.inspect
#      LOGGER.debug event.message.author.inspect
#      LOGGER.debug event.message.author.roles.inspect
#
#      if event.message.author.roles.find { |r| r.name == 'Admin' }
#        event.message.respond "Ack: #{event.message.content}"
#      else
#        event.message.respond "Not an admin, ignoring"
#      end
#    end

    # Event handler: A new invite is generated on any server.
    # TODO: Add invite to cache, and maybe kick off a salesforce sync to cache participant id?

    # Event handler: A new member was added to the server.
    @bot.member_join do |event|
      on_member_join(event)
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
      @servers = @bot.servers
      LOGGER.info "Logged in from #{ENV['APPLICATION_HOST'] || 'unknown host'} at #{@start_time}"

      init_invite_uses_cache unless @sync_and_exit

      if @sync_and_exit
        sync_salesforce
        exit
      end
    end
  rescue StandardError => e
    record_error(e)
  end

  def on_server_create(event)
    Honeycomb.start_span(name: 'bot.server_create') do |span|
      LOGGER.debug "Joined new server #{event.server.id}"
      Honeycomb.add_field('server.id', event.server.id)
      Honeycomb.add_field('servers.count', @bot.servers.count)

      # Update local caches for the new server.
      @servers = @bot.servers
      init_invite_uses_cache

      # Send a message to the #general channel asking for Admin permissions.
      send_to_general(
        event.server.id,
        "Please assign me Admin role to enable bot functionality."
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
      Honeycomb.add_field('user.id', user.id)
      Honeycomb.add_field('server.id', server.id)
      LOGGER.debug "Member join: '#{user.username}##{user.discriminator}' (#{user.id})"

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
        if found_invite
          LOGGER.warn "Multiple invites used, not sure who's who! Please fix members manually."
          Honeycomb.add_field('alert.multiple_invites_used', [found_invite.code, invite.code])
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
      program_ids = programs['records'].map { |program| program['Id'] }
      Honeycomb.add_field('program_ids.count', program_ids.count)
      LOGGER.debug "Syncing #{program_ids.count} programs from Salesforce"

      program_ids.each do |program_id|
        Honeycomb.start_span(name: 'bot.sync_salesforce.program') do |span|
          Honeycomb.add_field('program.id', program_id)
          # Fetch Discord server ID from the Program, skip if there isn't one.
          program_info = SalesforceAPI.client.get_program_info(program_id)
          server_id = program_info['Discord_Server_ID__c'].to_i
          Honeycomb.add_field('server.id', server_id)

          # Skip Programs that don't have a Discord Server ID.
          next if server_id == 0
          LOGGER.debug "Processing program #{program_id}"

          participants = SalesforceAPI.client.find_participants_by(program_id: program_id)
          Honeycomb.add_field('participants.count', participants.count)
          LOGGER.debug "Syncing #{participants.count} participants for program #{program_id}"

          participants.each do |participant|
            Honeycomb.start_span(name: 'bot.sync_salesforce.participant') do |span|
              Honeycomb.add_field('contact.id', participant.contact_id)
              Honeycomb.add_field('participant.discord_invite_code', participant.discord_invite_code)
              LOGGER.debug "Processing participant"

              # TODO: Have SFAPI.get_participants use SOQL so it returns the Participant ID directly.
              participant_id = SalesforceAPI.client.get_participant_id(participant.program_id, participant.contact_id)
              Honeycomb.add_field('participant.id', participant_id)

              if participant.discord_invite_code
                # Fetch the existing code if there is one.
                LOGGER.debug "Found existing invite for participant #{participant_id}"
                invite_code = participant.discord_invite_code
              else
                # Otherwise, create a new one and save it to the Participant record.
                LOGGER.debug "Creating new invite for participant #{participant_id}"
                invite_code = create_invite(server_id)
                SalesforceAPI.client.update_participant(participant_id, {'Discord_Invite_Code__c': invite_code})
              end

              Honeycomb.add_field('invite.code', invite_code)
            end
          end
        end
      end
      LOGGER.debug "Done syncing programs"
    end
  end

  # Given a Discord Member and an Invite, assign appropriate
  # Discord roles and an initial nickname for the Member on its server.
  # Note: May return on errors, so don't assume any call to this function was successful.
  def self.configure_member(member, invite)
    Honeycomb.start_span(name: 'bot.configure_member') do |span|
      server_id = member.server.id
      user = member.instance_variable_get(:@user)
      Honeycomb.add_field('server.id', server_id)
      Honeycomb.add_field('user.id', user.id)
      Honeycomb.add_field('invite.code', invite.code)

      # Try to map this invite to a Participant.
      # Always fetch latest info from SF, don't rely on a cache, so we're guaranteed to
      # have the latest name/role info at the time this runs.
      participant = SalesforceAPI.client.get_participant_info_by(discord_invite_code: invite.code)
      Honeycomb.add_field('participant.id', participant.id)
      Honeycomb.add_field('contact.id', participant.contact_id)
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
        SalesforceAPI.client.update_contact(participant.contact_id, {'Discord_User_ID__c': user.id})
      rescue RestClient::BadRequest => e
        LOGGER.warn "Attempted to reference same Discord user from multiple Contacts. Kicking the new user."
        record_error(e)
        LOGGER.warn "Probably a result of duplicate contacts, please fix the contacts."
        member.kick("Duplicate Contacts. Contact Support if you think this was a mistake.")
        return
      end

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

      # Fetch the Role objects from the Discord server, so we can add them to this user.
      roles = []

      # All but the Cohort roles are already created in the server.
      [participant_role, cohort_schedule_role].compact.each do |role_name|
        roles << DiscordBot.get_role(member.server, role_name)
      end

      # Cohort roles and channels may already exist, or we may have to create them.
      cohort_role = DiscordBot.get_or_create_cohort_role(member.server, cohort_role)
      if cohort_role
        roles << cohort_role
        DiscordBot.configure_cohort_channel(member, participant, cohort_role)
      end

      # Ignore missing roles.
      # This just means the participant didn't have a cohort schedule and/or
      # cohort assigned to them on Salesforce yet.
      roles.compact!
      Honeycomb.add_field('roles.count', roles.count)
      LOGGER.debug "Assigning #{roles.count} roles"

      member.set_roles(roles)
      member.set_nick(nick)

      # Once everything else is done, delete the invite, so it can't be used again.
      LOGGER.debug "Deleting invite"
      begin
        invite.delete
        Honeycomb.add_field('configure_member.invite_deleted', true)
      rescue Discordrb::Errors::UnknownInvite
        # Probably another instance of the bot got to it first.
        LOGGER.debug "Invite already deleted"
        Honeycomb.add_field('configure_member.invite_deleted', false)
      end
    end
  end

  #
  # Lower-level utilities.
  #
  # Helper functions used by top-level utilities, that contain enough logic that
  # we still want to be able to write specs for them.
  #

  # Generate a new invite for a given server, and update @invites.
  def create_invite(server_id)
    # Discord invites are attached to channels for some weird, probably legacy reason.
    # Always generate invites for the #general channel.
    general_channel = find_general_channel(server_id)
    # Last parameters are: temporary=false, unique=true.
    invite = general_channel.make_invite(INVITE_MAX_AGE, INVITE_MAX_USES, false, true)
    @invites[server_id] ||= {}
    @invites[server_id][invite.code] = invite.uses

    invite.code
  end

  def self.compute_nickname(contact)
    # Note: Nickname must be <= 32 characters.
    nick = "#{contact['Preferred_First_Name__c']} #{contact['LastName']}"
    if nick.length > 32
      # Try just using the first name, and if that's still too long, truncate
      # to 32 characters. This probably won't happen outside of test users?
      nick = "#{contact['Preferred_First_Name__c']}".slice(0, 32)
    end
  end

  # Participant role name
  def self.compute_participant_role(participant)
    # TODO: Factor out constants.
    case participant.role
    when :Fellow
      "Fellow"
    when :"Leadership Coach"
      "Leadership Coach"
    when :"Teaching Assistant"
      "Teaching Assistant"
    when :"Coaching Partner"
      "Coaching Partner"
    end
  end

  # Cohort Schedule role name
  def self.compute_cohort_schedule_role(participant)
    # 'Tuesday, 6pm' -> 'Tuesday'
    ll_day = (participant.cohort_schedule || '').split(',').first
    return unless ll_day

    # TODO: Factor out constants.
    case participant.role
    when :Fellow
      "Fellow: #{ll_day} LL"
    when :"Leadership Coach"
      "LC: #{ll_day} LL"
    end
  end

  # Cohort role name
  def self.compute_cohort_role(participant)
    return unless participant.cohort

    cohort_lcs = SalesforceAPI.client.get_cohort_lcs(participant.cohort)
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
      Honeycomb.add_field('role.name', name)
      LOGGER.debug "Fetching role '#{role_name}'"

      server.roles.find { |r| r.name == name }
    end
  end

  # Given an Cohort role name, return a Discord role.
  # Create the roles on the fly if they do not already exist on the given server.
  def self.get_or_create_cohort_role(server, role_name)
    Honeycomb.start_span(name: 'bot.get_or_create_cohort_role') do |span|
      Honeycomb.add_field('role.name', name)
      LOGGER.debug "Fetching/creating role"

      # Fetch the role if it already exists.
      role = server.roles.find { |r| r.name == name }

      # Otherwise, try to create it.
      unless role
        # TODO: Factor out contsants.
        template_role = server.roles.find { |r| r.name == 'Cohort: Template' }
        role = server.create_role(name: name, permissions: template_role.permissions)
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
    Honeycomb.start_span(name: 'bot.configure_cohort_channels') do |span|
      server = member.server

      Honeycomb.add_field('member.id', member.id)
      Honeycomb.add_field('user.id', member.instance_variable_get(:@user)&.id)
      Honeycomb.add_field('server.id', server.id)
      Honeycomb.add_field('contact.id', participant.contact_id)
      Honeycomb.add_field('program.id', participant.program_id)
      Honeycomb.add_field('role.name', role.name)
      LOGGER.debug "Ensuring proper channel:role configuration for '#{role.name}' role."

      # TODO: Factor out constants.
      # Cohort channel name is based on the role name, downcased, with spaces replaced
      # with dashes and all other non-alphabetical characters stripped.
      # 'Cohort: Susan Thursday' -> '#cohort-susan-thursday'
      channel_name = role.name
        .gsub(/ /, '-')
        .gsub(/[^\p{Alpha}-]/, '')
        .downcase

      # If the channel already exists, find it.
      channel = server.channels.find { |c| c.type == 0 && c.name == channel_name }

      # Default to not changing permission overwrites.
      permission_overwrites = {}

      # If the channel didn't exist, create it.
      unless channel
        LOGGER.debug "No existing Cohort channel found; creating one"
        # Cohort channels go in the 'Cohorts' channel category on the server.
        category = server.channels.find { |c| c.type == 4 && c.name == 'Cohorts' }
        channel = server.create_channel(
          channel_name,
          0,  # Channel type (0 = text)
          topic: "Private channel for #{role.name}",
          # Note: We don't set permission_overwrites, so the new channel will
          # inherit the permissions of its category parent (Cohorts).
          parent: category,
        )

        # Add an overwrite to give this role access to this channel.
        # This is a lot of steps, but we're just copying the permissions from the
        # "Cohort: Template" role and "#cohort-template" channel to the new role/channel.
        LOGGER.debug "Adding channel:role permission overwrite for '#{channel.name}'"
        template_channel = server.channels.find { |c| c.type == 0 && c.name == 'cohort-template' }
        template_role = server.roles.find { |r| r.name == 'Cohort: Template' }
        template_overwrite = template_channel.role_overwrites.find { |o| o.id == template_role.id }
        # Change the overwrite ID from the template role to the current role.
        template_overwrite.id = role.id
        permission_overwrites = channel.permission_overwrites
        permission_overwrites[template_overwrite.id] = Discordrb::Overwrite.from_other(template_overwrite)
      end

      # If this member is an LC, we also need an additional "permission overwrite" on
      # the private Cohort channel, to give them additional management permissions in
      # the channel. (We can't just have cohort-channel:LC-role permissions, because we
      # don't want LCs to have management permissions in all Cohort channels, only their own.)
      if participant.role == :"Leadership Coach"
        # Same as channel:role stuff above, we copy from a template permissions overwrite
        # to create a new channel:member permissions overwrite.
        LOGGER.debug "Adding channel:member permission overwrite, since participant is an LC"
        template_channel = server.channels.find { |c| c.type == 0 && c.name == 'cohort-template' }
        lc_template_role = server.roles.find { |r| r.name == 'Cohort: LC Template' }
        lc_template_overwrite = template_channel.role_overwrites.find { |o| o.id == lc_template_role.id }
        # Change overwrite type from 'role' to 'member', since the template is a role but
        # we're creating a member-specific overwrite.
        lc_template_overwrite.type = :member
        # Change the overwrite ID from the template role to the current member.
        lc_template_overwrite.id = member.id
        permission_overwrites ||= channel.permission_overwrites
        permission_overwrites[lc_template_overwrite.id] = Discordrb::Overwrite.from_other(lc_template_overwrite)
      end

      channel.permission_overwrites = permission_overwrites unless permission_overwrites.empty?

      Honeycomb.add_field('permission_overwrites', permission_overwrites.map { |k, v| v.to_hash })
      Honeycomb.add_field('channel.name', channel.name)
      LOGGER.debug "Permissions assigned"
    end
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
    @general_channels[server_id] ||= @servers[server_id].channels.find { |channel|
      # Channel type 0 is "text channel".
      channel.name == "general" && channel.type == 0
    }
  end

  # TODO: Delete this method (or remove hardcoded SERVER_ID), it's only used in development.
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
