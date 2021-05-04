# frozen_string_literal: true
# Global constants

# Roles
class RoleConstants
  # Global roles.
  ADMIN = :admin
  CAN_TAKE_ATTENDANCE_FOR_ALL = :CanTakeAttendanceForAll
  CAN_SYNC_FROM_SALESFORCE = :CanSyncFromSalesforce
  CAN_SEND_NEW_SIGNUP_EMAIL = :CanSendNewSignupEmail

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
