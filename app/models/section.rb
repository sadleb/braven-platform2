require 'canvas_api'

class Section < ApplicationRecord
  resourcify

  belongs_to :course

  # type cast these from strings to symbols to make the code cleaner
  attribute :section_type, :symbol

  before_validation { name.try(:strip!) }

  class Type
    COHORT = :cohort
    COHORT_SCHEDULE = :cohort_schedule
    TEACHING_ASSISTANTS = :teaching_assistants
    TA_CASELOAD = :ta_caseload
    DEFAULT_SECTION = :default_section
  end

  validates :name, :course_id, :section_type, presence: true
  validates :salesforce_id, length: {is: 18}, allow_blank: true
  validates :section_type, inclusion: {
    in: [
      Type::COHORT,
      Type::COHORT_SCHEDULE,
      Type::TEACHING_ASSISTANTS,
      Type::TA_CASELOAD,
      Type::DEFAULT_SECTION
    ], message: "'%{value}' is not a valid Section::Type"
  }

  scope :cohort_or_cohort_schedule, -> { where(section_type: [Type::COHORT, Type::COHORT_SCHEDULE]) }
  scope :cohort_schedule, -> { where(section_type: Type::COHORT_SCHEDULE) }
  scope :teaching_assistants, -> { where(section_type: Type::TEACHING_ASSISTANTS) }

  # Filter down to only sections with at least one User assigned a role for it.
  scope :with_users, -> { joins(:roles).distinct }

  # Sort names with numbers correctly. E.g. "C11 Blah" should come after "C2 Blah"
  # From https://stackoverflow.com/a/25042119/12432170.
  scope :order_by_name, -> {
    sort_by{ |section|
      section.name.gsub(/\d+/) { |s|
        # Left-pad numbers with zeroes.
        # 8 is arbitrarily longer than the numbers we'll see in titles.
        "%08d" % s.to_i
      }
    }
  }

  # All users, with any role, in this section.
  # This is a function just because I don't know how to write it as an association.
  def users
    all_users = []
    roles.distinct.map { |r| r.name }.each do |role_name|
      all_users += User.with_role(role_name, self)
    end
    all_users.uniq
  end

  # More efficient query if you want a specific role:
  def users_with_role(role_name)
    User.with_role(role_name, self)
  end

  def students
    users_with_role(RoleConstants::STUDENT_ENROLLMENT)
  end

  # Globally unique ID for this Section in Canvas. These are a composite of the
  # unique ID and the course ID so that we can create the same Section in both
  # the Accelerator Course and LC Playbook.
  # See here for more info: https://github.com/bebraven/platform/wiki/Salesforce-Sync
  def sis_id
    case section_type
    when Type::COHORT
      "SFCohortId_#{salesforce_id}_#{course.sis_id}"
    when Type::COHORT_SCHEDULE
      "SFCohortScheduleId_#{salesforce_id}_#{course.sis_id}"
    when Type::TA_CASELOAD
      "SFTAParticipantId_#{salesforce_id}_#{course.sis_id}"
    when Type::TEACHING_ASSISTANTS
      # These are special sections and don't have a Salesforce object
      "BVTAs_#{course.sis_id}"
    when Type::DEFAULT_SECTION
      # These are special sections and don't have a Salesforce object
      "BVDefault_#{course.sis_id}"

    # IMPORTANT: if you add more types here, make sure and update
    # the CreateSection#validate_arguments service
    else
      raise RuntimeError, "unrecognized section_type = #{section_type}"
    end
  end

  # Convenience method to easily be able to see the type of Salesforce Object that
  # the salesforce_id is for in traces.
  def salesforce_id_object
    case section_type
    when Type::COHORT
      'Cohort__c'
    when Type::COHORT_SCHEDULE
      'CohortSchedule__c'
    when Type::TA_CASELOAD
      'Participant__c'
    else
      nil
    end
  end

  def add_to_honeycomb_span(suffix = nil)
    attributes.each_pair { |attr, value| Honeycomb.add_field("section.#{attr}#{suffix}", value.to_s) }
    Honeycomb.add_field('section.sis_id', sis_id)
    Honeycomb.add_field('section.salesforce_id.object', salesforce_id_object)
  end
end
