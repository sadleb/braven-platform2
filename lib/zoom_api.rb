# frozen_string_literal: true
require 'rest-client'
require 'json'

# Implements the API for a JWT Zoom App setup at: https://marketplace.zoom.us/develop/create
# A JWT Zoom Appp "supports server-to-server integration with Zoom services without a need
# for user authorization."
class ZoomAPI
  BASE_URL = 'https://api.zoom.us/v2'
  class ZoomMeetingEndedError < StandardError; end
  class ZoomMeetingDoesNotExistError < StandardError; end
  class HostCantRegisterForZoomMeetingError < StandardError; end
  class RegistrationNotEnabledForZoomMeetingError < StandardError; end
  class BadZoomRegistrantFieldError < StandardError; end
  class TooManyRequestsError < StandardError; end

  # Use this to get an instance of the API client with authentication info setup.
  # The client's authentication is only valid for a short period of time.
  def self.client

    # The token is a JWT generated from the API KEY and SECRET. See here for
    # more info: https://marketplace.zoom.us/docs/guides/auth/jwt
    payload = {
      iss: Rails.application.secrets.zoom_api_key,
      exp: DateTime.now.to_i + 30.seconds
    }
    token = JWT.encode(payload, Rails.application.secrets.zoom_api_secret, 'HS256')

    new(token)
  end

  def initialize(auth_token)
    @global_headers = {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'Authorization' => "Bearer #{auth_token}",
    }
  end

  def get_meeting_info(meeting_id)
    get("/meetings/#{meeting_id}")
  end

  def add_registrant(meeting_id, email, first_name, last_name)
    registrant_details = {
      'first_name' => first_name,
      'last_name' => last_name,
      'email' => email
    }
    post("/meetings/#{meeting_id}/registrants", registrant_details)

  rescue RestClient::BadRequest,
         RestClient::TooManyRequests,
         RestClient::NotFound => e

    response = JSON.parse(e.http_body)

    case response['code']

    # {
    #   "code":300,
    #   "message":"Validation Failed.",
    #   "errors":[
    #     {"field":"email","message":"Invalid field."}
    #   ]
    # }
    when 300
      error_field = response.dig('errors', 0, 'field')
      error_message = response.dig('errors', 0, 'message')
      raise BadZoomRegistrantFieldError,
        "We cannot create a Zoom link for email: '#{email}' and Zoom Meeting ID = #{meeting_id}. " +
        "Zoom says the '#{error_field}' field is: #{error_message}"

    # {
    #   "code":404,
    #   "message":"Registration has not been enabled for this meeting: 85390989484."
    # }
    when 404
      raise RegistrationNotEnabledForZoomMeetingError,
        "We cannot create a Zoom link for email: '#{email}'. " +
        "Registration must be enabled for Zoom Meeting ID = #{meeting_id}. " +
        "Please go into the meeting settings, click Edit, and set 'Registration: Required'."

    # {
    #   "code":429,
    #   "message":"You have exceeded the daily rate limit of (3) for Add meeting registrant API requests for the registrant (email@example.com). You can resume these API requests at GMT 00:00:00."
    # }
    when 429
      raise TooManyRequestsError,
        "We temporarily cannot create a Zoom link for email: '#{email}' and Zoom Meeting ID = #{meeting_id}. " +
        "Try again tomorrow. Here is the Zoom API message: \"#{response['message']}\""

    # {
    #   "code":3001,
    #   "message":"Meeting does not exist: 85617842328."
    # }
    when 3001
      raise ZoomMeetingDoesNotExistError,
        "We cannot create a Zoom link for email: '#{email}'. " +
        "Zoom Meeting ID = #{meeting_id} doesn't exist. Maybe it was deleted or the ID is wrong?"

    # {
    #   "code":3027,
    #   "message":"Host can not register"
    # }
    when 3027
      raise HostCantRegisterForZoomMeetingError,
        "We cannot create a Zoom link for the host. " +
        "Email '#{email}' is a host for Meeting ID = #{meeting_id}"

    # {
    #   "code":3038,
    #   "message":"Meeting is over, you can not register now. If you have any questions, please contact the Meeting host."
    # }
    when 3038
      raise ZoomMeetingEndedError,
        "We cannot create a Zoom link for email: '#{email}'. The Zoom Meeting ID = #{meeting_id} has ended. " +
        "Please use a meeting in the future. If running a sync, the Meeting ID is set on the Cohort Schedule in Salesforce for this Participant."

    else
      raise
    end
  end

  def cancel_registrants(meeting_id, registrant_emails)
    registrants = registrant_emails.map { |registrant| {'email' => registrant } }
    path = "/meetings/#{meeting_id}/registrants/status"
    body = { 'action' => 'cancel', 'registrants' => registrants }
    put(path, body)
  rescue RestClient::NotFound => e

    response = JSON.parse(e.http_body)

    case response['code']

    # {
    #   "code":3001,
    #   "message":"Meeting does not exist: 85617842328."
    # }
    when 3001
      raise ZoomMeetingDoesNotExistError,
        "We cannot cancel the Zoom registration for email(s): '#{registrant_emails.inspect}'. " +
        "Zoom Meeting ID = #{meeting_id} doesn't exist. Maybe it was deleted or the ID is wrong?"

    else
      raise
    end
  end

  def get_registrants(meeting_id)
    result = get("/meetings/#{meeting_id}/registrants?page_size=300")
    raise NotImplementedError, 'Paged response returned and not implemented yet' if result['page_count'] && result['page_count'] > 1
    result
  end

# TODO: I think this was intended to fix up meetings with incorrect settings, but I don't
# think it's used. Revisit this and remove if there isn't a way to make things easier to support
# by running some automatic fix up code like this
# Task: https://app.asana.com/0/1174274412967132/1200467981732246
#  def update_meeting_for_registration(meeting_id)
#    Rails.logger.info("Updating meeting for registration: #{meeting_id}")
#    url = "#{BASE_URL}/meetings/#{meeting_id}"
#    data = {
#      'settings' => {
#        'approval_type' => 0,
#        'registration_type' => 2,
#        'registrants_email_notification' => false,
#        'registrants_confirmation_email' => false
#      }
#    }
#
#    put(url, data)
#  end

private

  def get(path, params = {}, headers = {})
    response = RestClient.get("#{BASE_URL}#{path}", {params: params}.merge(@global_headers.merge(headers)))
    extract_response(response)
  end

  def post(path, body, headers = {})
    response = RestClient.post("#{BASE_URL}#{path}", body.to_json, @global_headers.merge(headers))
    extract_response(response)
  end

  def put(path, body, headers = {})
    response = RestClient.put("#{BASE_URL}#{path}", body.to_json, @global_headers.merge(headers))
    extract_response(response)
  end

  def extract_response(response)
    (response.body.present? ? JSON.parse(response.body) : response)
  end

end
