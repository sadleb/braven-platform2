# frozen_string_literal: true

require 'rest-client'
require 'honeycomb-beeline'

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

  # TODO: change first_name to use Preferred_First_Name__c instead. Need to do this
  # for both the SFContact and the SFParticipant (i think) in order to get that to
  # be the thing used everywhere, which is what we want.
  # https://app.asana.com/0/1201131148207877/1201399664994349

  SFContact = Struct.new(:id, :email, :first_name, :last_name)

  SFParticipant = Struct.new(:first_name, :last_name, :email, :role,
                             :program_id, :contact_id, :status,
                             :cohort, :cohort_schedule, :cohort_id,
                             :id, :discord_invite_code, :discord_user_id, :discord_server_id,
                             :volunteer_role, :zoom_prefix,
                             :zoom_meeting_id_1, :zoom_meeting_id_2,
                             :zoom_meeting_link_1, :zoom_meeting_link_2,
                             :zoom_meeting_link_3,
                             :teaching_assistant_sections
                            ) do
    def add_to_honeycomb_span
      each_pair { |attr, value| Honeycomb.add_field("salesforce.participant.#{attr}", value) }
    end
  end

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
  MOCK_INTERVIEWER = :'Mock Interviewer'
  FIND_BY_ROLES = [LEADERSHIP_COACH, FELLOW, TEACHING_ASSISTANT]

  class ParticipantLookupError < StandardError; end
  class SalesforceDataError < StandardError; end
  ParticipantNotOnSalesforceError = Class.new(StandardError)
  ProgramNotOnSalesforceError = Class.new(StandardError)

  # Use this to get an authenticated instance of the API client
  def self.client
    @client_instance ||= new().authenticate
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
    with_invalid_session_handling do
      RestClient.get("#{@salesforce_url}#{path}", {params: params}.merge(@global_headers.merge(headers)))
    end
  end

  def post(path, body, headers={})
    with_invalid_session_handling do
      RestClient.post("#{@salesforce_url}#{path}", body, @global_headers.merge(headers))
    end
  end

  def put(path, body, headers={})
    with_invalid_session_handling do
      RestClient.put("#{@salesforce_url}#{path}", body, @global_headers.merge(headers))
    end
  end

  def patch(path, body, headers={})
    with_invalid_session_handling do
      RestClient.patch("#{@salesforce_url}#{path}", body, @global_headers.merge(headers))
    end
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

  # Wrap a RestClient call with handling for when the access_token becomes invalid.
  # We just refresh it.
  def with_invalid_session_handling &block

    # Original call.
    block.call()

  rescue RestClient::Unauthorized => e
    # The following error happens when the access_token becomes invalid and we need to
    # get a new one:
    # [{"message":"Session expired or invalid","errorCode":"INVALID_SESSION_ID"}]
    if e.http_body =~ /INVALID_SESSION_ID/
      Honeycomb.add_field('salesforce_api.retry_authentication', e.inspect)

      # Get a new access token. Note that since the client is just a singleton,
      # refreshing the auth for this instance effectively refreshes it for all consumers.
      authenticate()

      # Retry
      block.call()
    else
      raise
    end
  end

  # Gets a list of all Programs that have been launched with the Accelerator Course (and
  # most likely also a LC Playbook course) and are either currently running or will be in the future.
  #
  # @param [ActiveSupport::TimeWithZone] ended_less_than if you want to also get programs that
  #   ended recently, pass this parameter. E.g. the following would get all current and
  #   future programs as well as those that have ended within the past 45 days:
  #   SalesforceAPI.client.get_current_and_future_accelerator_programs(ended_less_than: 45.days.ago)
  def get_current_and_future_accelerator_programs(ended_less_than: nil)

    unless ended_less_than.nil?
      # Add a condition to the query to also get programs that ended after the Time offset
      # Note that the date is formatted as YYYY-MM-DD as specified here:
      # https://developer.salesforce.com/docs/atlas.en-us.234.0.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_select_dateformats.htm
      ended_less_than_condition = " OR Program_End_Date__c >= #{ended_less_than.strftime("%F")}"
    end

    soql_query =
      "SELECT Id, Name, Canvas_Cloud_Accelerator_Course_ID__c, Canvas_Cloud_LC_Playbook_Course_ID__c, Discord_Server_ID__c FROM Program__c " \
      "WHERE (RecordType.Name = 'Course' AND Canvas_Cloud_Accelerator_Course_ID__c <> NULL) " \
        "AND (Status__c IN ('Current', 'Future')#{ended_less_than_condition})"

    response = get("#{DATA_SERVICE_PATH}/query?q=#{CGI.escape(soql_query)}")
    response_json = JSON.parse(response.body)
    raise SalesforceDataError, "Got paginated response which isn't implemented" if response_json['nextRecordsUrl'].present?
    response_json['records']
  end

  # Gets a list of all Canvas Course IDs (both Accelerator and LC Playbook) that
  # are for Programs that are either currently running or will be in the future.
  # See get_current_and_future_accelerator_programs() for info on ended_less_than
  def get_current_and_future_canvas_course_ids(ended_less_than: nil)
    current_and_future_accelerator_programs = get_current_and_future_accelerator_programs(ended_less_than: ended_less_than)
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
  # See get_current_and_future_accelerator_programs() for info on ended_less_than
  def get_current_and_future_accelerator_canvas_course_ids(ended_less_than: nil)
    current_and_future_accelerator_programs = get_current_and_future_accelerator_programs(ended_less_than: ended_less_than)
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

  # Special convenience method for Discord.
  def get_program_id_by(discord_server_id:)
    # Clean the server ID first, since there's no parameterization here :(
    discord_server_id = discord_server_id.to_i
    soql_query = "SELECT Id FROM Program__c " \
                 "WHERE Discord_Server_Id__c = '#{discord_server_id}'"
    response = get("#{DATA_SERVICE_PATH}/query?q=#{CGI.escape(soql_query)}")
    program_record = JSON.parse(response.body)['records'][0]
    program_record ? program_record['Id'] : nil
  end

  def update_program(id, fields_to_set)
     patch("#{DATA_SERVICE_PATH}/sobjects/Program__c/#{id}", fields_to_set.to_json, JSON_HEADERS)
  end

  # - The "Id" is the Program.Id.
  # - Returns nil if not found
  # - Discards info from other programs if multiple have the same canvas_course_id.
  #   There is a validation on the Salesforce side that is meant to prevent this.
  # - There are no LC equivalents to these. e.g. They sign their Forms out-of-band before getting
  #   Confirmed as an LC.
  #
  # The "FA_ID_Fellow_Waivers__c" Salesforce API uses the field label "FA ID Fellow Forms" in Salesforce
  # We only updated the field label to use "Forms" instead of "Waivers" because updating
  # the API name that we grab here would add too much complexity
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

  def update_participant(id, fields_to_set)
     patch("#{DATA_SERVICE_PATH}/sobjects/Participant__c/#{id}", fields_to_set.to_json, JSON_HEADERS)
  end

  def update_candidate(candidate_id, fields_to_set)
    response = patch("#{DATA_SERVICE_PATH}/sobjects/Candidate__c/Id/#{candidate_id}", fields_to_set.to_json, JSON_HEADERS)
    JSON.parse(response.body)
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

  # See: https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/dome_upsert.htm
  def create_or_update_contact(email, fields_to_set)
     response = patch("#{DATA_SERVICE_PATH}/sobjects/Contact/Email/#{email}", fields_to_set.to_json, JSON_HEADERS)
     JSON.parse(response.body)
  end

  def create_candidate(fields_to_set)
    response = post("#{DATA_SERVICE_PATH}/sobjects/Candidate__c", fields_to_set.to_json, JSON_HEADERS)
    JSON.parse(response.body)
  end

  def create_participant(fields_to_set)
    response = post("#{DATA_SERVICE_PATH}/sobjects/Participant__c", fields_to_set.to_json, JSON_HEADERS)
    JSON.parse(response.body)
  end

  def create_ta_assignment(fields_to_set)
     response = post("#{DATA_SERVICE_PATH}/sobjects/TA_Assignment__c", fields_to_set.to_json, JSON_HEADERS)
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
  # Only finds participants with roles fellow, lc, or ta
  # TODO: rename to find_participants_by_program_id()
  # https://app.asana.com/0/1201131148207877/1201217979889312
  def find_participants_by(program_id:)
    if defined?(Rails) && Rails.respond_to?(:logger) && !caller_locations.first.path.include?('salesforce_api_spec.rb')
      raise ParticipantLookupError, "All participant lookups should be made using HerokuConnect::Participant,"\
      "except from the discord_bot because it doesn't have access to the HerokuConnect database."
    end
    participants = get_participants(program_id)

    ret = participants.map do |participant|
      if (participant['ParticipantStatus'].present? && FIND_BY_ROLES.include?(participant['Role']&.to_sym))
        SalesforceAPI.participant_to_struct(participant)
      end
    end
    ret.compact()
  end

  # Finds the Participant for a Contact in a Program.
  #
  # A Contact / Program pair should uniquely identify a Participant with any Role in the FIND_BY_ROLES array.
  # In other words, per program there should only be one Fellow, LC, or TA Participant per contact.
  # Returns the first found if there are duplicates and sends an alert to Honeycomb
  def find_participant(contact_id:, program_id:)
    if defined?(Rails) && Rails.respond_to?(:logger) && !caller_locations.first.path.include?('salesforce_api_spec.rb')
      raise ParticipantLookupError, "All participant lookups should be made using HerokuConnect::Participant,"\
      "except from the discord_bot because it doesn't have access to the HerokuConnect database."
    end
    raise ArgumentError.new('contact_id is nil') if contact_id.nil?
    raise ArgumentError.new('program_id is nil') if program_id.nil?

    participants = get_participants(program_id, contact_id)
    raise ParticipantNotOnSalesforceError, "Contact ID: #{contact_id}, Program ID: #{program_id}" if participants.empty?

    # only include participants with roles of fellow, leadership coach and teaching assistant
    participants = participants.filter { |p| FIND_BY_ROLES.include?(p['Role']&.to_sym)}

    if participants.count > 1
      Honeycomb.add_support_alert('salesforce_api.duplicate_participants_for_program',
                          "Duplicate participants encountered for Contact ID: #{contact_id}, Program ID: #{program_id}")
    end

    SalesforceAPI.participant_to_struct(participants.first)
  end

  # Note: passing nil for a link means "do nothing". If you want to clear it
  # out in Salesforce, pass an empty string.
  def update_zoom_links(id, link1, link2)
    # We probably want to cutover the Salesforce fields from "Webinar" to "Zoom" at some point.
    # That was just what they were called for Braven Booster. We call everything Zoom in the
    # platform code b/c that's what it is. Also, they are actually "Meetings" and not
    # Zoom "Webinars"
    body = {}
    body['Webinar_Access_1__c'] = link1 unless link1.nil?
    body['Webinar_Access_2__c'] = link2 unless link2.nil?
    update_participant(id, body)
  end

  # Turns a Participant hash as returned by Salesforce into an SFParticipant struct
  def self.participant_to_struct(participant)

    # IMPORTANT: if you change the attributes here, make sure and update
    # HerokuConnect::Participant.to_struct() as well.
    SFParticipant.new(participant['FirstName'], participant['LastName'],
                      participant['Email'], participant['Role']&.to_sym,
                      participant['ProgramId'], participant['ContactId'],
                      participant['ParticipantStatus'],
                      participant['CohortName'], participant['CohortScheduleDayTime'],
                      participant['CohortId'], participant['Id'],
                      nil, participant['DiscordUserId'], participant['DiscordServerId'],
                      participant['VolunteerRole'], participant['ZoomPrefix'],
                      participant['ZoomMeetingId1'], participant['ZoomMeetingId2'],
                      participant['ZoomMeetingLink1'], participant['ZoomMeetingLink2'],
                      participant['ZoomMeetingLink3'],
                      participant['TeachingAssistantSections'],
                     )
  end

  def self.participant_struct_to_contact_struct(participant)
    SalesforceAPI::SFContact.new(
      participant.contact_id,
      participant.email,
      participant.first_name,
      participant.last_name,
    )
  end

  def set_canvas_user_id(contact_id, canvas_user_id)
    body = { 'Canvas_Cloud_User_ID__c' => canvas_user_id }
    response = patch("#{DATA_SERVICE_PATH}/sobjects/Contact/#{contact_id}", body.to_json, JSON_HEADERS)
  end

  def create_campaign_member(fields_to_set)
     response = post("#{DATA_SERVICE_PATH}/sobjects/CampaignMember/Id", fields_to_set.to_json, JSON_HEADERS)
     JSON.parse(response.body)
  end

  def update_campaign_member(campaign_member_id, fields_to_set)
    patch("#{DATA_SERVICE_PATH}/sobjects/CampaignMember/#{campaign_member_id}", fields_to_set.to_json, JSON_HEADERS)
  end

  # TODO: remove the following three methods and cutover to use the HerokuConnect::Participant
  # versions: https://app.asana.com/0/1201131148207877/1201515686512765

  # Returns true if a SFParticipant struct is for an LC
  #
  # Note: other volunteer roles, like Coach Partner, use a Leadership Coach record type
  # in Salesforce and that's where "role" comes from, so we need to check the Volunteer_Role__c
  # as well.
  def self.is_lc?(salesforce_participant)
    salesforce_participant.role&.to_sym == SalesforceAPI::LEADERSHIP_COACH &&
      salesforce_participant.volunteer_role != SalesforceAPI::COACH_PARTNER
  end

  # Returns true if a SFParticipant struct is for a Teaching Assistant
  #
  # Note: at the time of writing, staff members are also setup with a TA
  # role. In the future, we may want to distinguish staff from actual TAs.
  def self.is_teaching_assistant?(salesforce_participant)
    salesforce_participant.role&.to_sym == SalesforceAPI::TEACHING_ASSISTANT
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
