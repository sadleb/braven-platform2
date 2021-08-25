# frozen_string_literal: true

###################
# Global constants
##################

# Roles
class RoleConstants
  # Global roles.
  ADMIN = :admin
  CAN_TAKE_ATTENDANCE_FOR_ALL = :CanTakeAttendanceForAll
  CAN_SYNC_FROM_SALESFORCE = :CanSyncFromSalesforce
  CAN_SEND_NEW_SIGNUP_EMAIL = :CanSendNewSignupEmail
  CAN_SCHEDULE_DISCORD = :CanScheduleDiscord

  # Local roles.
  TA_ENROLLMENT = :TaEnrollment
  STUDENT_ENROLLMENT = :StudentEnrollment

  # Add all section-level roles to this list.
  # I.e. anything that can be used like `user.add_role XXX_ENROLLMENT, section`.
  SECTION_ROLES = [
    STUDENT_ENROLLMENT,
    TA_ENROLLMENT,
    # TODO: https://app.asana.com/0/1174274412967132/1199945855038779
    # We need to introduce LC_ENROLLMENT here, Canvas, and Salesforce so it's
    # easier to distinguish between LCs and TAs.
  ]
end

# Sections
class SectionConstants
  DEFAULT_SECTION = 'Default Section'
  TA_SECTION = 'Teaching Assistants'
end

# LTI/Auth
class LtiConstants
  # Note: if you change this, keep it in sync with: app/javascript/packs/project_answers.js
  AUTH_HEADER_PREFIX = 'LtiState'
end

# Canvas
class CanvasConstants
  CANVAS_URL = Rails.application.secrets.canvas_url.freeze
  CAS_LOGIN_URL = "#{CANVAS_URL}/login/cas".freeze

  # We created a custom Account Role called "Staff Account" here:
  # https://braven.instructure.com/accounts/1/permissions
  # Use this ID with the CanvasAPI#make_admin() method to assign this role
  #
  # You can list available role_ids using:
  # https://canvas.instructure.com/doc/api/roles.html#method.role_overrides.api_index
  STAFF_ACCOUNT_ROLE_ID = 142
  ACCOUNT_ADMIN_ROLE_ID = 1
end

# Discord
class DiscordConstants
  # Add new servers here when we start a server for a new region/pilot.
  # To find the server ID, open the Discord server in a browser and find
  # the first ID part in the URL (e.g. discord.com/channels/SERVER_ID/CHANNEL_ID).
  # https://support.discord.com/hc/en-us/articles/206346498-Where-can-I-find-my-User-Server-Message-ID-

  TEST = 'Test'
  LEHMAN = 'Lehman'
  SJSU = 'SJSU'
  RUN = 'RU-N'
  NLU = 'NLU'
  BRAVENX = 'BravenX'
  BRAVEN_ONLINE = 'Braven Online'

  # Note these IDs overflow the javascript float64 type, so you should
  # always convert them to strings before sending to Honeycomb.
  TEST_ID = 722098701878689933
  LEHMAN_ID = 864951741447274546
  SJSU_ID = 864945788239740939
  RUN_ID = 864946359052009534
  NLU_ID = 0  # TODO
  BRAVENX_ID = 864945593797574706
  BRAVEN_ONLINE_ID = 864944991352520726

  ID_FROM_NAME = {
    "#{TEST}": TEST_ID,
    "#{LEHMAN}": LEHMAN_ID,
    "#{SJSU}": SJSU_ID,
    "#{RUN}": RUN_ID,
    "#{NLU}": NLU_ID,
    "#{BRAVENX}": BRAVENX_ID,
    "#{BRAVEN_ONLINE}": BRAVEN_ONLINE_ID,
  }

  NAME_FROM_ID = {
    TEST_ID => TEST,
    LEHMAN_ID => LEHMAN,
    SJSU_ID => SJSU,
    RUN_ID => RUN,
    NLU_ID => NLU,
    BRAVENX_ID => BRAVENX,
    BRAVEN_ONLINE_ID => BRAVEN_ONLINE,
  }

  # Keep these in a reasonable order, since they're displayed
  # this way in the dropdown in the UI.
  SERVERS = [
    # Regional
    [LEHMAN, LEHMAN_ID],
#    [NLU, NLU_ID],
    [RUN, RUN_ID],
    [SJSU, SJSU_ID],
    # Pilots
    [BRAVENX, BRAVENX_ID],
    [BRAVEN_ONLINE, BRAVEN_ONLINE_ID],
    # Test
    [TEST, TEST_ID],
  ]
end
