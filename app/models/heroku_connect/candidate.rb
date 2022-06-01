# frozen_string_literal: true

class HerokuConnect::Candidate < HerokuConnect::HerokuConnectRecord
  self.table_name = 'candidate__c'

  # type cast these from strings to symbols to make the code cleaner
  attribute :status__c, :symbol
  attribute :coach_partner_role__c, :symbol

  belongs_to :contact, foreign_key: 'contact__c'
  belongs_to :program, foreign_key: 'program__c'
  belongs_to :record_type, foreign_key: 'recordtypeid'
  has_one :participant, foreign_key: 'candidate__c'

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
      :participant__c,
      :program__c,
      :coach_partner_role__c # Currently called "Candidate Role Select" in the UI
    ]
  end

  # Possible values for status__c.
  class Status
    FULLY_CONFIRMED = :'Fully Confirmed'
    ACCEPTED = :Accepted
    WAITLISTED = :Waitlisted
    REJECTED = :Rejected
    OPTED_OUT = :'Opted Out'
  end

  # Their general Role category with Braven.
  # See SalesforceConstants::RoleCategory for more info
  def role_category
    record_type.name
  end

  # The actual, specific Role with Braven.
  # See SalesforceConstants::Role for more info.
  #
  # Note: This is calculated as either the "Candidate Role Select" which is used to
  # further qualify someone's general Role or their general Role if that's not set.
  # For legacy reasons, the "Candidate Role Select" is stored in the coach_partner_role__c field
  def role
    HerokuConnect::Candidate.calculate_role(coach_partner_role__c, role_category)
  end

  def self.calculate_role(candidate_role_select, record_type_name)
    candidate_role_select || record_type_name
  end

  def is_fellow?
    role == SalesforceConstants::Role::FELLOW
  end

  # Checks if they're an actual LC
  def is_lc?
    role == SalesforceConstants::Role::LEADERSHIP_COACH ||
    role == SalesforceConstants::Role::LC_SUBSTITUTE
  end

  # Checks if they're an actual TA, includes test user TAs
  def is_teaching_assistant?
    (role == SalesforceConstants::Role::TEACHING_ASSISTANT || role == :Test || role.empty?) && role_category == :"Teaching Assistant"
  end

  def is_staff?
    role == SalesforceConstants::Role::STAFF
  end

  # Checks if they're a faculty member, usually of a university such as a Professor.
  def is_faculty?
    role == SalesforceConstants::Role::FACULTY
  end

  def is_coach_partner?
    role == SalesforceConstants::Role::COACH_PARTNER
  end
end
