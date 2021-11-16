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
  CAN_SEND_ACCOUNT_CREATION_EMAILS = :CanSendAccountCreationEmails
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
  # TODO: rename to DEFAULT_TA_SECTION: https://app.asana.com/0/1201131148207877/1201324882801066
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
