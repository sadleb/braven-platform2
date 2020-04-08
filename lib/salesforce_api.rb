require 'rest-client'

class SalesforceAPI

  # Pass these into any POST or PUT request where the body is json.
  JSON_HEADERS = {content_type: :json, accept: :json}

  def initialize()
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
    # to Salesforce, either use the JWT/JWK bearer flow:
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
  end

  # Gets information about all current for future Participants in the program. These are folks who are
  # enrolled and should have Portal access.
  #
  # last_modified_since: specifies that we should only get data modified since this value.

  # TODO: ACTUALLY, need to figure out what format we need to use. The below format is what is sent back from SF
  # for the date, but need to make sure I can convert that to a SOQL query and filter on it.

  # The format is the Salesforce database datetime format in GMT. For example:
  #    2020-04-06T20:19:23.000+0000 
  # Also, it's only down to the second precision, not millisecond.
  def get_participant_data(last_modified_since = nil)
    query_params = (last_modified_since ? "?last_modified_since=#{last_modified_since}" : '')
    get("/services/apexrest/participants/currentandfuture/#{query_params}") # Defined in CourseParticipantInfoService apex class in Salesforce
  end

  # Same as get_participant_data(), but only for the specified course_id
  def get_participant_data_for_course(course_id, last_modified_since = nil)
    body = {
      "courseId" => "#{course_id}",
      "last_modified_since" => last_modified_since
    }
    post("/services/apexrest/participants/currentandfuture/", body.to_json, JSON_HEADERS) # Defined in CourseParticipantInfoService apex class in Salesforce
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

end
