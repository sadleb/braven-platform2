require 'lti_id_token'

# Stores info about an LTI launch so we can access that stuff in future calls
# in the context of that launch. See this for details about the LTI launch flow
# https://canvas.instructure.com/doc/api/file.lti_dev_key_config.html#launch-overview
class LtiLaunch < ApplicationRecord
  serialize :id_token_payload, JSON

  # This is the Redirect URI that must be configured in the Developer Key for the LTI
  # and must match EXACTLY.
  LTI_LAUNCH_REDIRECT_URI="https://#{Rails.application.secrets.application_host}/lti/launch".freeze
  BRAVEN_ISS="https://#{Rails.application.secrets.application_host}".freeze

  scope :authenticated, -> { where.not id_token_payload: nil }
  scope :unauthenticated, -> { where id_token_payload: nil }

  # The fully authenticated LtiLaunch for this state (aka launch session).
  # This method used to be called `LtiLaunch.current`.
  def self.from_state(state)
    launch = LtiLaunch.where(state: state).authenticated.first
  end

  # IMPORTANT NOTE: Never use the LtiLaunch returned from this function to
  # log someone in! Only use `from_state` or `authenticate` for that!
  # This is only for looking up launches to find the associated Canvas course/
  # assignment IDs for LtiAdvantage or similar usecases.
  def self.from_id(user, id)
    # We use `where` instead of `find` so we can use the `authenticated`
    # scope, but since we're selecting by ID, the `where` will only ever
    # return one or zero launches.
    launch = LtiLaunch.where(id: id&.to_i).authenticated.first
    # ONLY return this LtiLaunch if it's owned by the current user.
    if user && launch&.user == user
      launch
    end
  end

  # Alias for current but returns false if there is no authenticated LtiLaunch for this "state"
  def self.is_valid?(state)
     # TODO: need to expire launches. They shouldn't be valid forever. Maybe only 2 weeks.
     # Actually, we should just clear out launch records from the database periodically,
     # whatever the valid length of time we choose. No reason for the launches table to grow
     # forever. The state parameters are sent in the iframed URL and authentication header so
     # an attacker could theoretically brute force a login, which makes it more important to
     # to not have them valid forever.
     # Task: https://app.asana.com/0/1174274412967132/1184057808812020

     ll = LtiLaunch.where(state: state).authenticated.first
     (ll.present? ? ll : false)
  end

  # Authenticates an LtiLaunch with the id_token sent from the platform
  def self.authenticate(state, id_token)
    idt = LtiIdToken.parse_and_verify(id_token)
    launch = LtiLaunch.find_by!(state: state)
    launch.id_token_payload = idt.payload

    # The initial target uri in the login doesn't always match the actual target in the payload so update it. E.g. assignment selection
    launch.target_link_uri = idt.target_link_uri

    # TODO: hitting the back button seems to make Canvas do the launch again. You have to hit back twice.
    # There may be another solution, like the redirect needs to be done differently from launch to target link uri,
    # but another solution would be to clear the nonce on the authenticate and if the nonce is missing then redirect
    # back to canvas ourselves.

    launch.save!
    launch
  end

  # Returns the parse request message payload of the launch
  def request_message
    @request_message ||= LtiIdToken.parse(id_token_payload)
  end

  def resource_link_request_message
    raise ArgumentError.new, 'Wrong LTI launch message type. Must be a launch of a ResourceLink.' unless request_message.is_a?(LtiResourceLinkRequestMessage)
    request_message
  end

  # The user that this launch is for.
  def user
    User.find_by(canvas_user_id: request_message&.canvas_user_id)
  end

# TODO: get rid of the following two accessors. Just have everyone use the request_message or resource_link_request_message
# Or if we keep them, rename them to be canvas_assignment_id and canvas_course_id to be consistent.

  # Assignment and Course IDs are used for attaching Rise360ModuleInteractions
  # to the appropriate module. Return nil if the ID was not an integer.
  def assignment_id
    resource_link_request_message.canvas_assignment_id
  end

  def course_id
    resource_link_request_message.canvas_course_id
  end

  # True if this is an LtiLaunch that doesn't have access to normal Devise session based authentication
  # and needs to use the "state" parameter as the effective authentication token.
  def sessionless?
    !!sessionless
  end

  # Returns a unique identifier for us when issuing and JWT
  def braven_iss
    BRAVEN_ISS
  end

  # Returns the parameters needed in Step 2 of the LTI Launch flow in order
  # to do the handshake with the LTI platform (aka Canvas) and "login" / authenitcate
  # an LTI launch / session. See:
  # http://www.imsglobal.org/spec/security/v1p0/#step-2-authentication-request
  def auth_params
    {
      :scope => 'openid',                    # OIDC Scope
      :response_type => 'id_token',          # OIDC response is always an id token
      :response_mode => 'form_post',         # OIDC response is always a form post
      :prompt => 'none',                     # Don't prompt user on redirect
      :client_id => client_id,
      :redirect_uri => LTI_LAUNCH_REDIRECT_URI,  # URL to return to after login
      :state => state,                       # State to identify the launch session. Note: may be multiple per browser session
      :nonce => nonce,                       # Prevent replay attacks
      :login_hint =>  login_hint,            # Login hint to identify platform (aka Canvas) session
      :lti_message_hint => lti_message_hint  # Used by platform (aka Canvas) to store / identify context on their end. Opaque to us.
    }
  end

  # Adds common Honeycomb fields to every span in the trace for this launch.
  # Useful to be able to group any particular field you're querying for by launch info
  #
  # IMPORTANT: if you're in a trace that will send these same fields for multiple
  # courses, assignments, users, etc in different spans, use a more specific name for those fields.
  # Something like 'my_class.canvas.course.id'. This method will overwrite the following fields for
  # every span in the trace so you for example you would get the 'canvas.assignment.id' values set
  # to 555 everywhere even if you set it to 444 in some span.
  def add_to_honeycomb_trace
    Honeycomb.add_field_to_trace('canvas.course.id', resource_link_request_message.canvas_course_id.to_s)
    Honeycomb.add_field_to_trace('canvas.assignment.id', resource_link_request_message.canvas_assignment_id.to_s)
    Honeycomb.add_field_to_trace('canvas.user.id', resource_link_request_message.canvas_user_id.to_s)
    Honeycomb.add_field_to_trace('canvas.user.roles', resource_link_request_message.canvas_roles)
  end
end

