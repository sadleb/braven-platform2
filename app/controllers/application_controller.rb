require 'rubycas-server-core/tickets'
require 'canvas_api'

class ApplicationController < ActionController::Base
  include RubyCAS::Server::Core::Tickets
  include DryCrud::Controllers
  include Pundit
  # Custom error handling.
  include Rescuable

  before_action :authenticate_user!
  before_action :add_honeycomb_fields
  after_action :remove_x_frame_options

  # This callback is a development helper that complains if an action has not explicitly
  # called `authorize`. It is *not* a fallback mechanism, and should not be relied upon
  # for added security. Its only purpose is to remind us to call `authorize` in each action.
  # The `unless` param excludes CasSessionsController from this check, since we have no
  # reason to call authorize in devise or CAS controller acitons.
  after_action :verify_authorized, unless: :devise_controller?

  private

  def authenticate_user!
    super unless authenticated_by_token? || cas_ticket?
  end

  def authenticated_by_token?
    return false unless request.format.symbol == :json

    key = params[:access_key] || request.headers['Access-Key']
    return false if key.nil?

    access_token = AccessToken.find_by(key: key)
    return false unless access_token

    sign_in(:user, access_token.user)
    true
  end

  def cas_ticket?
    ticket = params[:ticket]
    return false if ticket.nil?

    ServiceTicket.exists?(ticket: ticket)
  end

  # This is defined by :database_authenticable on the User model, but we're using :cas_authenticatable
  # However, we still want to support account creation, registration, and confirmation which is
  # database_authenticable functionality so we need to define this for those built-in views to work.
  def new_session_path(_)
    new_user_session_path
  end
  helper_method :new_session_path

  def canvas_url
    CanvasConstants::CANVAS_URL
  end
  helper_method :canvas_url

  # This is just the main login path that redirects back to the endpoint you are trying to hit right
  # now after you have logged in.
  # e.g. https://platform.braven.org/cas/login?service=https%3A%2F%2Fplatform.braven.org%2Fcourses%2F1
  def cas_login_url
    ::Devise.cas_client.add_service_to_login_url(::Devise.cas_service_url(request.url, devise_mapping))
  end
  helper_method :cas_login_url

  # Honeycomb's auto-instrumentation is nice and adds a bunch of common stuff we need to troubleshoot,
  # but here is a place to add anything that's specific to our environment (or missing from the
  # auto-instrumentation) that would also help
  #
  # Note that Honeycomb.add_field() auto-prefixes with 'app'. E.g. 'app.user.id'
  def add_honeycomb_fields

    # Add the common fields that uniquely identify the user to every span in the trace. It's nice
    # to be able to group whatever you're querying for by user. Depending on the flow or support
    # ticket information, one or the other of these common fields may be more convenient to use.
    current_user&.add_to_honeycomb_trace()

    # Add the common fields for this LtiLaunch to every span in the trace. E.g. canvas_assignment_id.
    # Careful: If you run any logic in an endpoint authenticated using an LtiLaunch where it
    # loops over multiple assignments, courses, or users and sends the appropriate IDs
    # to Honeycomb, make sure you use different Honeycomb fields then this sends b/c this
    # will clobber all that and just overwrite them with the LtiLaunch values for those fields
    # in all spans in the trace.
    @lti_launch&.add_to_honeycomb_trace()

    # Add the HTTP request ID to the current span, so that it doesn’t get an `app` prefix
    # and matches the built-in `request` namespace that the Rails integration uses.
    Honeycomb.current_span&.add_field('request.id', request.request_id)
  end

  # Remove the default X-Frame-Options header Rails adds. We use CSP instead.
  # See config/initializers/content_security_policy.rb
  # Technically, CSP should take precedence anyway, but this is down to browser implementation, so
  # better to not take chances.
  def remove_x_frame_options
    response.headers.delete "X-Frame-Options"
  end

  # For LTI authentication (esp in a browser without access to cookies / session), the
  # state param is the de-facto "authenticated session" identifier. It is used to look up
  # the LtiLaunch for context on this "session"
  def current_state_param
    # TODO: the state param may be in one of three places, see: config/initializers/lti_authentication.rb
    # Abstract that out into a common utility / way for any controller or lib or service to be able to
    # access the state param of the current request. Perhaps using middleware? Like TracePropagation::Middleware does?
    # https://app.asana.com/0/1174274412967132/1191053265938819
    params[:state]
  end
  helper_method :current_state_param

end
