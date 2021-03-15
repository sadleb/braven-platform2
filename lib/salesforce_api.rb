# frozen_string_literal: true

require 'rest-client'

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
                             :cohort, :cohort_schedule)
  SFProgram = Struct.new(:id, :name, :school_id, :fellow_course_id,
                         :leadership_coach_course_id,
                         :leadership_coach_course_section_name, :timezone,
                         :pre_accelerator_qualtrics_survey_id,
                         :post_accelerator_qualtrics_survey_id)

  ENROLLED = 'Enrolled' 
  DROPPED = 'Dropped'
  COMPLETED = 'Completed'
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
  end

  # Gets a list of all Accelerator Programs (not LC Programs) that have been launched (aka
  # they have a Canvas Course ID set) and are either currently running or will be in the future.
  def get_current_and_future_accelerator_programs()
    soql_query = 
      "SELECT Id, Name, Highlander_Accelerator_Course_ID__c FROM Program__c " \
      "WHERE RecordType.Name = 'Course' AND Highlander_Accelerator_Course_ID__c <> NULL AND Status__c IN ('Current', 'Future')"

    response = get("#{DATA_SERVICE_PATH}/query?q=#{CGI.escape(soql_query)}")
    response_json = JSON.parse(response.body)
    raise SalesforceDataError, "Got paginated response which isn't implemented" if response_json['nextRecordsUrl'].present?
    response_json
  end

  # TODO: remove the Qualtrics IDs from here. We don't use them anymore.
  def get_program_info(program_id)
    soql_query = 
      "SELECT Id, Name, Highlander_Accelerator_Course_ID__c, Highlander_LCPlaybook_Course_ID__c, School__c, " \
        "Section_Name_in_LMS_Coach_Course__c, Default_Timezone__c, " \
        "Preaccelerator_Qualtrics_Survey_ID__c, Postaccelerator_Qualtrics_Survey_ID__c " \
      "FROM Program__c WHERE Id = '#{program_id}'"

    response = get("#{DATA_SERVICE_PATH}/query?q=#{CGI.escape(soql_query)}")
    JSON.parse(response.body)['records'][0]
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
                 "WHERE Highlander_Accelerator_Course_ID__c = '#{canvas_course_id}'"
    response = get("#{DATA_SERVICE_PATH}/query?q=#{CGI.escape(soql_query)}")
    JSON.parse(response.body)['records'][0]
  end

  # Gets a list of all Participants in the Program. These are folks who are
  # enrolled and should have Portal access.
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

  # Get information about a Contact record
  def get_contact_info(contact_id)
    response = get("#{DATA_SERVICE_PATH}/sobjects/Contact/#{contact_id}" \
      "?fields=Id,FirstName,LastName,Email,Phone,BZ_Region__c,Preferred_First_Name__c,CreatedDate,Signup_Date__c," \
      "IsEmailBounced,BZ_Geographical_Region__c,Current_Employer__c,Career__c,Title,Job_Function__c,Current_Major__c," \
      "High_School_Graduation_Date__c,Anticipated_Graduation__c,Graduate_Year__c")
    JSON.parse(response.body)
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

  # Get the associated Accelerator Canvas course ID for the specified 
  # LC Playbook Canvas course ID.
  def get_accelerator_course_id_from_lc_playbook_course_id(lc_playbook_course_id)
    soql_query = 
      "SELECT Highlander_Accelerator_Course_ID__c " \
      "FROM Program__c WHERE Highlander_LCPlaybook_Course_ID__c = '#{lc_playbook_course_id}'"

    response = get("#{DATA_SERVICE_PATH}/query?q=#{CGI.escape(soql_query)}")
    record = JSON.parse(response.body)['records'][0]
    return record ? record['Highlander_Accelerator_Course_ID__c'] : nil
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
    raise ProgramNotOnSalesforceError if program.nil?

    SFProgram.new(program['Id'], program['Name'], program['SchoolId'],
              program['Highlander_Accelerator_Course_ID__c'].to_i,
              program['Highlander_LCPlaybook_Course_ID__c'].to_i,
              program['Section_Name_in_LMS_Coach_Course__c'],
              program['Default_Timezone__c'].to_sym,
              program['Preaccelerator_Qualtrics_Survey_ID__c'],
              program['Postaccelerator_Qualtrics_Survey_ID__c'],
    )
  end

  def find_contact(id:)
    contact = get_contact_info(id)
    SFContact.new(contact['Id'], contact['Email'], contact['FirstName'], contact['LastName'])
  end

  def find_participants_by(program_id:)
    participants = get_participants(program_id)

    participants.map do |participant|
      SFParticipant.new(participant['FirstName'], participant['LastName'],
                      participant['Email'], participant['Role'].to_sym,
                      participant['ProgramId'], participant['ContactId'],
                      participant['ParticipantStatus'], participant['StudentId'],
                      participant['CohortName'], participant['CohortScheduleDayTime'])
    end
  end


  def find_participant(contact_id:)
    participants = get_participants(nil, contact_id)
    raise ParticipantNotOnSalesForceError, "Contact ID #{contact_id}" if participants.empty?

    # TODO: Figure out the criteria for in case of many participants
    participant = participants.first

    SFParticipant.new(participant['FirstName'], participant['LastName'],
                      participant['Email'], participant['Role'].to_sym,
                      participant['ProgramId'], participant['ContactId'],
                      participant['ParticipantStatus'], participant['StudentId'],
                      participant['CohortName'], participant['CohortScheduleDayTime'])
  end

  def set_canvas_user_id(contact_id, canvas_user_id)
    body = { 'Canvas_User_ID__c' => canvas_user_id }
    response = patch("#{DATA_SERVICE_PATH}/sobjects/Contact/#{contact_id}", body.to_json, JSON_HEADERS)
  end

  def set_canvas_course_ids(program_id, canvas_fellow_course_id, canvas_lc_course_id)
    body = {
      'Highlander_Accelerator_Course_ID__c' => canvas_fellow_course_id,
      'Highlander_LCPlaybook_Course_ID__c' => canvas_lc_course_id,
    }
    patch("#{DATA_SERVICE_PATH}/sobjects/Program__c/#{program_id}", body.to_json, JSON_HEADERS)
  end


# TODO: delete me if we don't need to use a POST for any reason. I figured out how to accept query params in the get after I had implement this.
# I'm assuming we'll be fine sending the request to SF in a get and not need this, but just in case I"m leaving this around until we've fully
# implemented the flow and know we won't use it.
#  # Same as get_participant_data(), but only for the specified course_id
#  def get_participant_data_for_course(course_id, last_modified_since = nil)
#    body = {
#      "courseId" => "#{course_id}",
#      "last_modified_since" => last_modified_since
#    }
#    post("/services/apexrest/participants/currentandfuture/", body.to_json, JSON_HEADERS) # Defined in BZ_ProgramParticipantInfoService apex class in Salesforce
#  end

end
