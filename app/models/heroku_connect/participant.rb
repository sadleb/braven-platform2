# frozen_string_literal: true
require 'salesforce_api'

class HerokuConnect::Participant < HerokuConnect::HerokuConnectRecord
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

  # Returns a list of Contact full names for each TA Caseload(full_name) section they should
  # be addded to in Canvas. Reimplements the logic for the :teaching_assistant_sections
  # field returned from the SalesforceAPI#get_participants() APEX endpoint.
  def teaching_assistant_sections

    # This Participant is a TA with a caseload. Just return their name in the array since
    # that's the only TA Caseload(name) Canvas section they need to go in
    return [full_name] if ta_caseloads.exists?

    if ta_assignments.exists?
      return ta_assignments.each.map { |tassign| "#{tassign.ta_participant.full_name}" }
    end

    return []
  end

  # TODO: cutover the app/services/sync_xxx classes to use these Salesforce models
  # directly instead of the SalesforceAPI::SFParticipant (and other) structs.
  # Task: https://app.asana.com/0/1201131148207877/1201453841518463
  #
  # Queries the necessary tables to build a SalesforceAPI::SFParticipant struct
  # @return [SalesforceAPI::SFParticipant]
  def to_struct
    SalesforceAPI::SFParticipant.new(contact.firstname, contact.lastname, contact.email,
      role, program__c, contact__c, status__c,
      'TODO_remove_student_id_from_struct_and_canvas_api',
      cohort.name, cohort_schedule.canvas_section_name,
      cohort__c, sfid, discord_invite_code, contact.discord_user_id__c, program.discord_server_id__c,
      candidate.candidate_role.to_s, cohort.zoom_prefix,
      cohort_schedule.webinar_registration_1__c, cohort_schedule.webinar_registration_2__c,
      webinar_access_1__c, webinar_access_2__c, teaching_assistant_sections
    )
  end

private

  # Note: the discord_invite_code is/was used in the discordbot which uses the SalesforceAPI
  # It's a secret and we should be limiting where it's stored / available (b/c it allows access
  # to our Discord servers). We're deprecating it and should remove from the struct once we
  # rip out/cutover the discord invite code stuff.
  def discord_invite_code
    :deprecated_discord_invite_code
  end
end
