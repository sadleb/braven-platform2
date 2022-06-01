# frozen_string_literal: true

class HerokuConnect::Participant < HerokuConnect::HerokuConnectRecord
  include ParticipantSyncInfo::SyncScope

  self.table_name = 'participant__c'

  # type cast these from strings to symbols to make the code cleaner
  attribute :status__c, :symbol

  belongs_to :contact, foreign_key: 'contact__c'
  belongs_to :cohort, foreign_key: 'cohort__c'
  belongs_to :cohort_schedule, foreign_key: 'cohort_schedule__c'
  belongs_to :candidate, foreign_key: 'candidate__c'
  belongs_to :program, foreign_key: 'program__c'
  belongs_to :record_type, foreign_key: 'recordtypeid'
  has_many :ta_assignments, foreign_key: 'fellow_participant__c'
  has_many :ta_caseloads, foreign_key: 'ta_participant__c', class_name: 'HerokuConnect::TaAssignment'

  # IMPORTANT: Add columns you want to select by default here. If a new
  # Salesforce field is mapped in Heroku Connect that you want to use,
  # it must be added to this list.
  #
  # See HerokuConnect::HerokuConnectRecord for more info
  def self.default_columns
    [
      :id, :sfid, :createddate, :isdeleted,
      :name,
      :status__c,
      :recordtypeid,
      :contact__c,
      :candidate__c,
      :program__c,
      :cohort__c,
      :cohort_schedule__c,
      :webinar_access_1__c,
      :webinar_access_2__c,
      :webinar_access_3__c
    ]
  end

  alias_attribute :program_id, :program__c
  alias_attribute :contact_id, :contact__c
  alias_attribute :zoom_meeting_link_1, :webinar_access_1__c
  alias_attribute :zoom_meeting_link_2, :webinar_access_2__c
  alias_attribute :zoom_meeting_link_3, :webinar_access_3__c

  scope :find_participant, ->(contact_id, program_id) {
    find_by(program__c: program_id, contact__c: contact_id)
  }

  # PRO-TIP: when debugging, use the `attributes` method for one of these to see the values.
  # E.g. HerokuConnect::Participant.with_discord_info.find_participant(contact_id, program_id).attributes
  # Without the `.attributes` added on at the end you want be able to see the joined info when printing the
  # participant even though you do have access to those attributes
  scope :with_discord_info, -> {
    joins(:contact, :program)
    .select(
      'contact.discord_user_id__c as discord_user_id',
      'program__c.discord_server_id__c as discord_server_id'
    )
  }

  TA_CASELOAD_SECTION_PREFIX = 'TA Caseload'

  # Possible values for the status__c
  class Status
    ENROLLED = :Enrolled
    DROPPED = :Dropped
    COMPLETED = :Completed
    FAILED = :Failed
  end

  # Convenience method to get their actual full name instead of the "name" column, b/c
  # that's the name of the record which could be something like: "P: Firstname Lastname : Fall 2021"
  def full_name
    contact.name
  end

  # Alias for the record_type.name
  # See SalesforceConstants::RoleCategory for more info
  def role_category
    record_type.name
  end

  # Checks if they're an actual LC
  def is_lc?
    candidate.is_lc?
  end

  # Checks if they're an actual TA.
  def is_teaching_assistant?
    candidate.is_teaching_assistant?
  end

  def is_staff?
    candidate.is_staff?
  end

  # Checks if they're a faculty member, usually of a university such as a Professor.
  def is_faculty?
    candidate.is_faculty?
  end

  def is_coach_partner?
    candidate.is_coach_partner?
  end

  def add_to_honeycomb_span(suffix = nil)
    Honeycomb.add_field("salesforce.participant.id#{suffix}", sfid)
    attributes.each_pair do |attr, value|
      # These are HerokuConnect attributes that are meaningless
      # (and confusing if named salesforce.participant.id for example)
      next if attr == 'id' || attr == 'isdeleted'

      Honeycomb.add_field("salesforce.participant.#{attr}#{suffix}", value.to_s)
    end
  end

  # A TA can be assigned to a group of Fellows using TaAssignment__c Salesforce
  # records. If they have assignments, a section will be created locally and in Canvas
  # with this name so they can filter the gradebook down to their assigned Fellows.
  def ta_caseload_section_name
    unless role_category == SalesforceConstants::RoleCategory::TEACHING_ASSISTANT
      raise RuntimeError.new(
        "Only '#{SalesforceConstants::RoleCategory::TEACHING_ASSISTANT}' Participants have a ta_caseload_section_name"
      )
    end
    HerokuConnect::Participant.ta_caseload_section_name_for(full_name)
  end

  def self.ta_caseload_section_name_for(ta_name)
    "#{TA_CASELOAD_SECTION_PREFIX}(#{ta_name})"
  end

end
