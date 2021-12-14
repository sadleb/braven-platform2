# frozen_string_literal: true
require 'salesforce_api'

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

  # Possible values for candidate_role
  class Role
    FELLOW = HerokuConnect::Participant::Role::FELLOW
    LEADERSHIP_COACH = HerokuConnect::Participant::Role::LEADERSHIP_COACH
    TEACHING_ASSISTANT = HerokuConnect::Participant::Role::TEACHING_ASSISTANT
    MOCK_INTERVIEWER = HerokuConnect::Participant::Role::MOCK_INTERVIEWER
    COACH_PARTNER = :'Coach Partner'
    LC_SUBSTITUTUE = :'LC Substitute'
    TEST = :Test
    PANELIST = :Panelist
  end

  # Heroku Connect can't sync formula fields so we're reimplementing the logic of
  # "Volunteer_Role__c" here (which is now called Candidate Role in the UI).
  # If there is a "Candidate Role" set, use that. Otherwise, use the `RecordType.name`
  # of the Candidate (aka Teaching Assistant, Fellow, etc)
  def candidate_role
    coach_partner_role__c || record_type.name
  end
end
