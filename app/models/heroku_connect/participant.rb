# frozen_string_literal: true
require 'salesforce_api'

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
      :webinar_access_1__c, :webinar_access_2__c,
    ]
  end

  # Possible values for the status__c
  class Status
    ENROLLED = :Enrolled
    DROPPED = :Dropped
    COMPLETED = :Completed
  end

  # Possible values for the #role (aka record_type.name)
  # IMPORTANT: if you add roles here, make sure and add them to
  # HerokuConnect::Candidate::Role too.
  class Role
    FELLOW = :Fellow
    LEADERSHIP_COACH = :'Leadership Coach'
    TEACHING_ASSISTANT = :'Teaching Assistant'
    MOCK_INTERVIEWER = :'Mock Interviewer'
  end

  # Alias for the record_type.name
  # See HerokuConnect::Participant::Role for example values.
  def role
    record_type.name
  end

  # Convenience method to get their actual full name instead of the "name" column, b/c
  # that's the name of the record which could be something like: "P: Firstname Lastname : Fall 2021"
  def full_name
    contact.name
  end

  # TODO: remove the following three methods from SalesforceAPI and cutover all usage to these ones.
  # https://app.asana.com/0/1201131148207877/1201515686512765

  # Note: at the time of writing, staff members are also setup with a TA
  # role. In the future, we may want to distinguish staff from actual TAs.
  def is_teaching_assistant?
    role == Role::TEACHING_ASSISTANT
  end

  # Note: Coach Partner's are a Leadership Coach record type in Salesforce
  # Their Candidate Role is used to distinguish them from actual LCs.
  def is_coach_partner?
    candidate_role == HerokuConnect::Candidate::Role::COACH_PARTNER
  end

  # Note: candidate_roles, like Coach Partner, use a Leadership Coach record type
  # in Salesforce so we need to check that as well.
  def is_lc?
    role == Role::LEADERSHIP_COACH &&
    (
      candidate_role == HerokuConnect::Candidate::Role::LEADERSHIP_COACH ||
      candidate_role == HerokuConnect::Candidate::Role::LC_SUBSTITUTE
    )
  end

end
