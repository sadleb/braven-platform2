# frozen_string_literal: true

require 'rest-client'

# TODO: Get rid of ActiveSupport dependency in this lib.
require "active_support"
require "active_support/core_ext/object"

# Allows you to call into the Salesforce API and retrieve information.
# Example Usage:
# contact_info = SalesforceAPI.client.get_contact_info('some_sf_contact_id')
class SalesforceAPI

  # Pass these into any POST or PUT request where the body is json.
  JSON_HEADERS = {content_type: :json, accept: :json}

  DATA_SERVICE_PATH = '/services/data/v49.0'

  SFContact = Struct.new(:id, :email, :first_name, :last_name)
  SFParticipant = Struct.new(:first_name, :last_name, :email, :role,
                             :program_id, :contact_id, :status, :student_id,
                             :cohort, :cohort_schedule, :cohort_id,
                             :id, :discord_invite_code, :discord_user_id,
                             :volunteer_role, :zoom_prefix,
                             :zoom_meeting_id_1, :zoom_meeting_id_2,
                             :zoom_meeting_link_1, :zoom_meeting_link_2,
                            )
  SFProgram = Struct.new(:id, :name, :school_id, :fellow_course_id,
                         :leadership_coach_course_id,
                         :leadership_coach_course_section_name, :timezone,
                         :pre_accelerator_qualtrics_survey_id,
                         :post_accelerator_qualtrics_survey_id)

  ENROLLED = 'Enrolled'
  DROPPED = 'Dropped'
  COMPLETED = 'Completed'
  COACH_PARTNER = 'Coach Partner'
  LEADERSHIP_COACH = :'Leadership Coach'
  FELLOW = :Fellow
  TEACHING_ASSISTANT = :'Teaching Assistant'

  class SalesforceDataError < StandardError; end
  ParticipantNotOnSalesForceError = Class.new(StandardError)
  ProgramNotOnSalesforceError = Class.new(StandardError)

  # TODO: Figure out how to make this work with a single instance
  # @client = nil

  # Use this to get an authenticated instance of the API client
  def self.client
    # A sloppy singleton
    # if @client.nil?
    #   s = new
    #   @client = s.authenticate
    # end
    # @client
    s = new
    s.authenticate
  end

  def authenticate
    # For authentication against the Salesforce API we use what is called a Session ID token as detailed here:
    # https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/quickstart_oauth.htm
    auth_params = {
      :grant_type => 'password',
      :client_id => ENV['SALESFORCE_PLATFORM_CONSUMER_KEY'],
      :client_secret => ENV['SALESFORCE_PLATFORM_CONSUMER_SECRET'],
      :username => ENV['SALESFORCE_PLATFORM_USERNAME'],
      :password => ENV['SALESFORCE_PLATFORM_PASSWORD'] + ENV['SALESFORCE_PLATFORM_SECURITY_TOKEN']
    }

    # TODO: this endpoint is really only supposed to be for dev env testing. Once we figure out how to hookup this stuff
    # to Salesforce, ideally switch to use the JWT/JWK bearer flow:
    #  - https://help.salesforce.com/articleView?id=remoteaccess_oauth_jwt_flow.htm&type=5
    # or one of the other OAuth flows if we want the access token to be on a per user basis.
    #  - https://help.salesforce.com/articleView?id=remoteaccess_oauth_flows.htm&type=5
    token_response = RestClient.post("https://#{ENV['SALESFORCE_HOST']}/services/oauth2/token", auth_params)
    token_response_json = JSON.parse(token_response.body)

    # There are generic Salesforce URLs like:
    #  - https://login.salesforce.com
    #  - https://test.salesforce.com
    # But when using the API we need to hit the actual instance our Salesforce account is hosted on. E.g.
    #  - https://na74.my.salesforce.com/
    #  - https://bebraven--Staging.cs22.my.salesforce.com
    @salesforce_url = token_response_json['instance_url']
    @access_token = token_response_json['access_token']
    @global_headers = { 'Authorization' => "Bearer #{@access_token}" }
    self
  end

  def get(path, params={}, headers={})
    RestClient.get("#{@salesforce_url}#{path}", {params: params}.merge(@global_headers.merge(headers)))
  end

  def post(path, body, headers={})
    RestClient.post("#{@salesforce_url}#{path}", body, @global_headers.merge(headers))
  end

  def put(path, body, headers={})
    RestClient.put("#{@salesforce_url}#{path}", body, @global_headers.merge(headers))
  end

  def patch(path, body, headers={})
    RestClient.patch("#{@salesforce_url}#{path}", body, @global_headers.merge(headers))
  rescue RestClient::InternalServerError => e
    # The following transient error happens when two things are trying to update the same
    # Salesforce record: https://developer.salesforce.com/forums/?id=9060G000000I2r1QAC
    #   [{"message":"unable to obtain exclusive access to this record or 1 records: 0035cFAKESFIDAAI",
    #     "errorCode":"UNABLE_TO_LOCK_ROW","fields":[]}]
    # Let's just wait a little and try again to see if these generally go away.
    if e.http_body =~ /UNABLE_TO_LOCK_ROW/
      Honeycomb.add_field('salesforce_api.retry_success', false)
      sleep 0.5
      result = RestClient.patch("#{@salesforce_url}#{path}", body, @global_headers.merge(headers))
      Honeycomb.add_field('salesforce_api.retry_success', true)
      result
    else
      raise
    end
  end

  # Gets a list of all Programs that have been launched with the Accelerator Course (and
  # most likely also a LC Playbook course) and are either currently running or will be in the future.
  def get_current_and_future_accelerator_programs()
    soql_query =
      "SELECT Id, Name, Canvas_Cloud_Accelerator_Course_ID__c, Canvas_Cloud_LC_Playbook_Course_ID__c, Discord_Server_ID__c FROM Program__c " \
      "WHERE RecordType.Name = 'Course' AND Canvas_Cloud_Accelerator_Course_ID__c <> NULL AND Status__c IN ('Current', 'Future')"

    response = get("#{DATA_SERVICE_PATH}/query?q=#{CGI.escape(soql_query)}")
    response_json = JSON.parse(response.body)
    raise SalesforceDataError, "Got paginated response which isn't implemented" if response_json['nextRecordsUrl'].present?
    response_json['records']
  end

  # Gets a list of all Canvas Course IDs (both Accelerator and LC Playbook) that
  # are for Programs that are either currently running or will be in the future.
  def get_current_and_future_canvas_course_ids()
    current_and_future_accelerator_programs = get_current_and_future_accelerator_programs()
    canvas_course_ids = []
    unless current_and_future_accelerator_programs.empty?
      current_and_future_accelerator_programs.each { |p|
        canvas_course_ids << p['Canvas_Cloud_Accelerator_Course_ID__c']
        canvas_course_ids << p['Canvas_Cloud_LC_Playbook_Course_ID__c']
      }.uniq.compact
    end
    canvas_course_ids
  end

  # Gets a list of all Accelerator Canvas Course IDs (not the LC Playbook courses) that
  # are either currently running or will be in the future.
  def get_current_and_future_accelerator_canvas_course_ids()
    current_and_future_accelerator_programs = get_current_and_future_accelerator_programs()
    canvas_course_ids = []
    unless current_and_future_accelerator_programs.empty?
      canvas_course_ids = current_and_future_accelerator_programs.map { |p|
        p['Canvas_Cloud_Accelerator_Course_ID__c']
      }.uniq.compact
    end
    canvas_course_ids
  end

  # TODO: remove the Qualtrics IDs from here. We don't use them anymore.
  def get_program_info(program_id)
    # If the program ID is invalid, return without making an API call.
    # This prevents SOQLi on program_id (like "1'; DROP TABLE Program__c").
    # We just return nil instead of raising bc that's how this function acts
    # for "program not found".
    return unless program_id.match? /^[a-zA-Z0-9]{18}$/
    soql_query =
      "SELECT Id, Name, Canvas_Cloud_Accelerator_Course_ID__c, Canvas_Cloud_LC_Playbook_Course_ID__c, School__c, " \
        "Section_Name_in_LMS_Coach_Course__c, Default_Timezone__c, Discord_Server_ID__c, " \
        "Preaccelerator_Qualtrics_Survey_ID__c, Postaccelerator_Qualtrics_Survey_ID__c " \
      "FROM Program__c WHERE Id = '#{program_id}'"

    response = get("#{DATA_SERVICE_PATH}/query?q=#{CGI.escape(soql_query)}")
    JSON.parse(response.body)['records'][0]
  end

  def update_program(id, fields_to_set)
     patch("#{DATA_SERVICE_PATH}/sobjects/Program__c/#{id}", fields_to_set.to_json, JSON_HEADERS)
  end

  # - The "Id" is the Program.Id.
  # - Returns nil if not found
  # - Discards info from other programs if multiple have the same canvas_course_id.
  #   There is a validation on the Salesforce side that is meant to prevent this.
  # - There are no LC equivalents to these. e.g. They sign their waivers out-of-band before getting
  #   Confirmed as an LC.
  def get_fellow_form_assembly_info(canvas_course_id)
    soql_query = "SELECT Id, FA_ID_Fellow_PostSurvey__c, FA_ID_Fellow_PreSurvey__c, FA_ID_Fellow_Waivers__c " \
                 "FROM Program__c " \
                 "WHERE Canvas_Cloud_Accelerator_Course_ID__c = '#{canvas_course_id}'"
    response = get("#{DATA_SERVICE_PATH}/query?q=#{CGI.escape(soql_query)}")
    JSON.parse(response.body)['records'][0]
  end

  # Gets a list of ALL Participants in the Program regardless of Status. Use find_participants_by(program_id)
  # to get an easier to process list of SFParticipant structs for only those with a Status that may require
  # sync'ing (aka filters out the empty Status folks).
  #
  # program_id: if specified, filters the Participants returned down to only that Program. E.g. a2Y1J000000YpQFUA0
  # contact_id: if specified, filters the Participants returned down to only that Contact. E.g. 0037A00000RUoz4QAD
  # last_modified_since: specifies that we should only get participants whose info has been  modified since this value.

  # TODO: need to figure out what format we need to use. The below format is what is sent back from SF
  # for the date, but need to make sure I can convert that to a SOQL query and filter on it.

  # The format is the Salesforce database datetime format in GMT. For example:
  #    2020-04-06T20:19:23.000+0000
  # Also, it's only down to the second precision, not millisecond.
  def get_participants(program_id = nil, contact_id = nil, last_modified_since = nil)
    query_params = ''
    if program_id || contact_id || last_modified_since
      query_params = '?'
      query_params += "program_id=#{program_id}&" if program_id
      query_params += "contact_id=#{contact_id}&" if contact_id
      query_params += "last_modified_since=#{CGI.escape(last_modified_since)}&" if last_modified_since
      query_params.chop! # Remove the trailing &
    end
    # Defined in BZ_ProgramParticipantInfoService Apex class in Salesforce
    response = get("/services/apexrest/participants/currentandfuture/#{query_params}")
    JSON.parse(response.body)
  end

  def get_participant_id(program_id, contact_id)
    soql_query = "SELECT Id FROM Participant__c " \
                 "WHERE Program__r.Id = '#{program_id}' AND Contact__r.Id = '#{contact_id}'"
    response = get("#{DATA_SERVICE_PATH}/query?q=#{CGI.escape(soql_query)}")
    participant_record = JSON.parse(response.body)['records'][0]
    participant_record ? participant_record['Id'] : nil
  end

  # Special convenience method for Discord Bot.
  def get_participant_info_by(discord_invite_code:)
    # Clean the invite code first, since there's no parameterization here :(
    discord_invite_code = discord_invite_code.gsub(/[^a-zA-Z0-9]/, '')
    soql_query = "SELECT Id, Contact__c, Program__c FROM Participant__c " \
                 "WHERE Discord_Invite_Code__c = '#{discord_invite_code}'"
    response = get("#{DATA_SERVICE_PATH}/query?q=#{CGI.escape(soql_query)}")
    participant_record = JSON.parse(response.body)['records'][0]
    if participant_record
      info = get_participants(participant_record['Program__c'], participant_record['Contact__c'])
      if info
        participant = SalesforceAPI.participant_to_struct(info[0])
        participant.id = participant_record['Id']
        participant
      end
    end
  end

  def update_participant(id, fields_to_set)
     patch("#{DATA_SERVICE_PATH}/sobjects/Participant__c/#{id}", fields_to_set.to_json, JSON_HEADERS)
  end

  # Get information about a Contact record
  def get_contact_info(contact_id)
    response = get("#{DATA_SERVICE_PATH}/sobjects/Contact/#{contact_id}" \
      "?fields=Id,FirstName,LastName,Email,Phone,BZ_Region__c,Preferred_First_Name__c,CreatedDate,Signup_Date__c," \
      "IsEmailBounced,BZ_Geographical_Region__c,Current_Employer__c,Career__c,Title,Job_Function__c,Current_Major__c," \
      "High_School_Graduation_Date__c,Anticipated_Graduation__c,Graduate_Year__c,Discord_User_ID__c")
    JSON.parse(response.body)
  end

  # Get secret signup token from a Contact record.
  # This is not included in get_contact_info because there's no need
  # to fetch this sensitve information in generic contact record requests.
  def get_contact_signup_token(contact_id)
    response = get("#{DATA_SERVICE_PATH}/sobjects/Contact/#{contact_id}" \
      "?fields=Signup_Token__c")
    JSON.parse(response.body)['Signup_Token__c']
  end

  # Gets a list of all CohortSchedule's for a Program. The names returned are what the Canvas section
  # should be called when setting up placeholder sections until the actual cohorts are mapped.
  def get_cohort_schedule_section_names(program_id)
    initial_api_path = "#{DATA_SERVICE_PATH}/query?q=SELECT+DayTime__c+FROM+CohortSchedule__c+WHERE+Program__r.Id='#{program_id}'"
    recursively_map_soql_column_to_array('DayTime__c', [], initial_api_path)
  end

  # Gets a list of the names of all Cohorts available for the specified Program.
  def get_cohort_names(program_id)
    initial_api_path = "#{DATA_SERVICE_PATH}/query?q=SELECT+Name+FROM+Cohort__c+WHERE+Program__r.Id='#{program_id}'"
    recursively_map_soql_column_to_array('Name', [], initial_api_path)
  end

  def get_cohort_lcs(cohort_id)
    # If the cohort ID is invalid, return without making an API call.
    # This prevents SOQLi on cohort_id (like "1'; DROP TABLE Program__c").
    # We just return nil instead of raising bc that's how this function acts
    # for "cohort not found".
    return unless cohort_id.match? /^[a-zA-Z0-9]{18}$/

    soql_query =
      "SELECT FirstName__c, LastName__c " \
        "FROM Participant__c " \
        "WHERE RecordTypeId IN (" \
        "  SELECT Id FROM RecordType WHERE Name = 'Leadership Coach'" \
        ") AND Cohort__c = '#{cohort_id}'"

    response = get("#{DATA_SERVICE_PATH}/query?q=#{CGI.escape(soql_query)}")
    JSON.parse(response.body)['records']
  end

  # Get the associated Accelerator Canvas course ID for the specified
  # LC Playbook Canvas course ID.
  def get_accelerator_course_id_from_lc_playbook_course_id(lc_playbook_course_id)
    soql_query =
      "SELECT Canvas_Cloud_Accelerator_Course_ID__c " \
      "FROM Program__c WHERE Canvas_Cloud_LC_Playbook_Course_ID__c = '#{lc_playbook_course_id}'"

    response = get("#{DATA_SERVICE_PATH}/query?q=#{CGI.escape(soql_query)}")
    record = JSON.parse(response.body)['records'][0]
    return record ? record['Canvas_Cloud_Accelerator_Course_ID__c'] : nil
  end

  # Recursively pages the API in a SOQL query for a particular column
  # builds up an array of the results. The initial call to this should be with the query path
  # and then this calls itself with the next path if necessary.
  #
  # See: https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/dome_query.htm
  def recursively_map_soql_column_to_array(column_name, existing_array, api_path)
    result = existing_array
    if api_path
      response_json = JSON.parse(get(api_path).body)
      new_array = result + response_json['records'].map { |rs| rs[column_name] }
      result = recursively_map_soql_column_to_array(column_name, new_array, response_json['nextRecordsUrl'])
    end
    result
  end

  def find_program(id:)
    program = get_program_info(id)
    raise ProgramNotOnSalesforceError, "Program ID: #{id} not found on Salesforce. Please enter a valid Program ID" if program.nil?

    SFProgram.new(program['Id'], program['Name'], program['SchoolId'],
              program['Canvas_Cloud_Accelerator_Course_ID__c'].to_i,
              program['Canvas_Cloud_LC_Playbook_Course_ID__c'].to_i,
              program['Section_Name_in_LMS_Coach_Course__c'],
              program['Default_Timezone__c'].to_sym,
              program['Preaccelerator_Qualtrics_Survey_ID__c'],
              program['Postaccelerator_Qualtrics_Survey_ID__c'],
    )
  end

  # See: https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/dome_upsert.htm
  def create_or_update_contact(email, fields_to_set)
     response = patch("#{DATA_SERVICE_PATH}/sobjects/Contact/Email/#{email}", fields_to_set.to_json, JSON_HEADERS)
     JSON.parse(response.body)
  end

  def update_contact(id, fields_to_set)
     patch("#{DATA_SERVICE_PATH}/sobjects/Contact/#{id}", fields_to_set.to_json, JSON_HEADERS)
  end

  def find_contact(id:)
    contact = get_contact_info(id)
    SFContact.new(contact['Id'], contact['Email'], contact['FirstName'], contact['LastName'])
  end

  # Gets a list SFParticipant structs for Participant records that have a Status set.
  def find_participants_by(program_id:)
    participants = get_participants(program_id)

    ret = participants.map do |participant|
      if (participant['ParticipantStatus'].present?)
        SalesforceAPI.participant_to_struct(participant)
      end
    end
    ret.compact()
  end


  def find_participant(contact_id:, program_id: nil)
    participants = get_participants(program_id, contact_id)
    raise ParticipantNotOnSalesForceError, "Contact ID #{contact_id}" if participants.empty?

    # TODO: Figure out the criteria for in case of many participants
    participant = participants.first

    SalesforceAPI.participant_to_struct(participant)
  end

  def update_zoom_links(id, link1, link2)
    # We probably want to cutover the Salesforce fields from "Webinar" to "Zoom" at some point.
    # That was just what they were called for Braven Booster. We call everything Zoom in the
    # platform code b/c that's what it is. Also, they are actually "Meetings" and not
    # Zoom "Webinars"
    update_participant(id, { 'Webinar_Access_1__c' => link1, 'Webinar_Access_2__c' => link2 })
  end

  # Turns a Participant hash as returned by Salesforce into an SFParticipant struct
  def self.participant_to_struct(participant)
    SFParticipant.new(participant['FirstName'], participant['LastName'],
                      participant['Email'], participant['Role']&.to_sym,
                      participant['ProgramId'], participant['ContactId'],
                      participant['ParticipantStatus'], participant['StudentId'],
                      participant['CohortName'], participant['CohortScheduleDayTime'],
                      participant['CohortId'], participant['Id'],
                      participant['DiscordInviteCode'], participant['DiscordUserId'],
                      participant['VolunteerRole'], participant['ZoomPrefix'],
                      participant['ZoomMeetingId1'], participant['ZoomMeetingId2'],
                      participant['ZoomMeetingLink1'], participant['ZoomMeetingLink2'],
                     )
  end

  def set_canvas_user_id(contact_id, canvas_user_id)
    body = { 'Canvas_Cloud_User_ID__c' => canvas_user_id }
    response = patch("#{DATA_SERVICE_PATH}/sobjects/Contact/#{contact_id}", body.to_json, JSON_HEADERS)
  end

  def set_canvas_course_ids(program_id, canvas_fellow_course_id, canvas_lc_course_id)
    body = {
      'Canvas_Cloud_Accelerator_Course_ID__c' => canvas_fellow_course_id,
      'Canvas_Cloud_LC_Playbook_Course_ID__c' => canvas_lc_course_id,
    }
    patch("#{DATA_SERVICE_PATH}/sobjects/Program__c/#{program_id}", body.to_json, JSON_HEADERS)
  end

  def create_campaign_member(fields_to_set)
     response = post("#{DATA_SERVICE_PATH}/sobjects/CampaignMember/Id", fields_to_set.to_json, JSON_HEADERS)
     JSON.parse(response.body)
  end

  def update_campaign_member(campaign_member_id, fields_to_set)
    patch("#{DATA_SERVICE_PATH}/sobjects/CampaignMember/#{campaign_member_id}", fields_to_set.to_json, JSON_HEADERS)
  end

  # Returns true if a SFParticipant struct is for an LC
  #
  # Note: other volunteer roles, like Coach Partner, use a Leadership Coach record type
  # in Salesforce and that's where "role" comes from, so we need to check the Volunteer_Role__c
  # as well.
  def self.is_lc?(salesforce_participant)
    salesforce_participant.role&.to_sym == SalesforceAPI::LEADERSHIP_COACH &&
      salesforce_participant.volunteer_role != SalesforceAPI::COACH_PARTNER
  end

  # Returns true if a SFParticipant struct is for a Coach Partner
  #
  # Note: Coach Partner's are a Leadership Coach record type in Salesforce and
  # that's where "role" comes from, so we need to check the Volunteer_Role__c
  # as well.
  def self.is_coach_partner?(salesforce_participant)
    salesforce_participant.role&.to_sym == SalesforceAPI::LEADERSHIP_COACH &&
      salesforce_participant.volunteer_role == SalesforceAPI::COACH_PARTNER
  end
end
