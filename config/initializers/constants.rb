# frozen_string_literal: true
# Global constants

# Roles
class RoleConstants
  TA_ENROLLMENT = :TaEnrollment
  STUDENT_ENROLLMENT = :StudentEnrollment

  # Add all section-level roles to this list.
  # I.e. anything that can be used like `user.add_role XXX_ENROLLMENT, section`.
  SECTION_ROLES = [
    STUDENT_ENROLLMENT,
    TA_ENROLLMENT,
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
