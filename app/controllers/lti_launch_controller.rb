# Implement the LTI 1.3 Launch Flow. Here is a nice summary of that flow by Canvas, our LMS:
# https://canvas.instructure.com/doc/api/file.lti_dev_key_config.html#launch-overview
#
# Summary of flow:
# Step 1: Login Initiation - Canvas calls into here letting us know a launch is starting
# Step 2: Authentication Response - We initiate an handshake to authenticate the launch establish a trust in the launch
# Step 3: LTI Launch - The launch is initated with meta-data about the context and the final target resource to launch
# Step 4: Resource Display - We display the target resource
class LtiLaunchController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  LTI_ISS=Rails.application.secrets.lti_oidc_base_uri
  LTI_AUTH_RESPONSE_URL="#{Rails.application.secrets.lti_oidc_base_uri}/api/lti/authorize_redirect".freeze

  # POST /lti/login
  #
  # This is the OIDC url Canvas is calling in Step 1 above.
  def login
    authorize LtiLaunch
    raise ActionController::BadRequest.new(), "Unexpected iss parameter: #{params[:iss]}" if params[:iss] != LTI_ISS

    @lti_launch = LtiLaunch.create!(params.except(:iss, :canvas_region).permit(:client_id, :login_hint, :target_link_uri, :lti_message_hint)
                                         .merge(:state => LtiLaunchController.generate_state, :nonce => SecureRandom.hex(10)))

    # Step 2 in the flow, do the handshake
    redirect_to "#{LTI_AUTH_RESPONSE_URL}?#{@lti_launch.auth_params.to_query}"
  end


  # POST /lti/launch
  #
  # This is the endpoint configured as the Redirect URI in the Canvas Developer Key. It's Step 3 in the launch flow.
  def launch
    params.require([:id_token, :state])

    # This also verifies the request is coming from Canvas using the public JWK
    # as described in Step 3 here: https://canvas.instructure.com/doc/api/file.lti_dev_key_config.html
    ll = LtiLaunch.authenticate(params[:state], params[:id_token])

    # The launch redirects to the target url with the state param, so even though we call this
    # here and it'll be in this trace, the real place where the LtiLaunch Honeycomb fields are
    # being added for target endpoint is in app/controllers/application_controller.
    ll&.add_to_honeycomb_trace()

    # Sign in the user on Platform. Note that if third party cookies aren't allowed in the
    # browser this will have no effect and the LtiAuthentication::WardenStrategy will be used
    # for each request to authenticate them instead of using session.
    sign_in_from_lti(ll)

    authorize ll, policy_class: LtiLaunchPolicy

    # Step 4 in the flow, show the target resource now that we've saved the id_token payload that contains
    # user identifiers, course contextual data, custom data, etc.
    target_uri = URI(ll.target_link_uri)

    # We have three different paths we can choose at this point, based on the
    # target URI:
    case target_uri.path

    # 1. For pages that are loaded by hardcoded LTI placements (not dynamically
    # created assignments), and don't have a "always open in a new tab" setting,
    # like Attendance and Course Resources, render a form here with a button that
    # opens a new tab and POSTs the state parameter so that it doesn't show up
    # in the URL. Additionally, add an lti_launch_id param (see #3 below) to identify
    # the launch on the new page. We're technically duplicating information here
    # by passing both the state and the ID, but it makes it easier to handle the
    # path in the #redirector action, so whatever.
    when /#{launch_attendance_event_submissions_path}/, /#{lti_course_resources_path}/
      case target_uri.path
      when /#{launch_attendance_event_submissions_path}/
        @resource_name = 'Attendance'
      when /#{lti_course_resources_path}/
        @resource_name = 'Course Resources'
      else
        @resource_name = 'this resource'
      end

      @state = ll.state
      return render :redirect_form, layout: 'lti_canvas'

    # 2. For the Grade Details page, since it always opens inside a Canvas iframe,
    # and there's not an easy way to accidentally share the direct link to the Platform
    # page, AND making people click a button to open the details in a new tab would
    # be painful for anyone going through the speedgrader, we still put the state
    # param directly into the URL. The same goes for the CLASS assignment where we
    # show the Zoom link. We don't want to add the friction of having to open it in
    # a new tab to access the link. See course_attendance_events_controller#open_in_new_tab
    # TEMP FIX: And the same for other things that show up in the grade details view
    # (aka submission view), and nowhere else...
    when /#{rise360_module_grade_path('')}/,
         /#{launch_attendance_event_submission_answers_path}/,
         /#{course_project_version_project_submission_path('.*', '')}\d+$/,
         /#{survey_submission_path('')}\d+$/,
         /#{completed_waiver_submissions_path}/,
         /#{completed_preaccelerator_survey_submissions_path}/,
         /#{completed_postaccelerator_survey_submissions_path}/,
         /#{capstone_evaluation_submission_path('')}\d+$/,
         /#{fellow_evaluation_submission_path('')}\d+$/
      append_query_param(target_uri, "state=#{params[:state]}")

    # 3. For everyting else, redirect directly with an LTI Launch ID param.
    # The key difference between the state param and the ID param is that the state
    # param authenticates you (through the LTI middleware), while the ID param
    # only identifies the launch and will only be used if it belongs to the
    # currently logged-in user. Note that we're making a big assumption here
    # that any other link will be from a Canvas Assignment with the "open in
    # new tab" setting turned on. Always use that setting for LTI assignments!
    else
      append_query_param(target_uri, "lti_launch_id=#{ll.id}")
    end

    redirect_to target_uri.to_s
  end

  # POST /lti/redirector
  #
  # This is to be used ONLY by the form rendered in #launch above.
  def redirector
    params.require([:state])

    state = params[:state]

    ll = LtiLaunch.from_state(state)

    # Sign in the user on Platform.
    # We do this again because when they were logged in from the #launch action,
    # they were most likely inside an iframe, and the cookie we set would have
    # been blocked as 3rd-party. Now that we're outside an iframe, we have to
    # set a new cookie.
    sign_in_from_lti(ll)

    authorize ll, policy_class: LtiLaunchPolicy

    # Parse the target URI back out of the LtiLaunch and add the launch ID param.
    target_uri = URI(ll.target_link_uri)
    append_query_param(target_uri, "lti_launch_id=#{ll.id}")

    # Render a page with a redirect meta tag, instead of redirecting from the
    # controller, to fix Safari not setting cookies correctly if a page isn't
    # rendered.
    @redirect_uri = target_uri.to_s
    render :redirect, layout: 'lti_canvas'
  end

  # Generates a globally unique value to use in the "state" parameter of an LTI Launch. This uniquely identifies
  # an authenticated session so it must be long enough to prevent brute force attacks.
  def self.generate_state
    "#{Base64.urlsafe_encode64(SecureRandom.uuid)}#{SecureRandom.urlsafe_base64(96)}" # 32+96=128 chars
  end

  private

  # Pass in a URI::Generic object to modify in-place.
  # https://launchschool.medium.com/object-passing-in-ruby-pass-by-reference-or-pass-by-value-6886e8cdc34a
  def append_query_param(uri, param)
    if uri.query
      uri.query += "&#{param}"
    else
      uri.query = "#{param}"
    end
  end

  # Grab the user ID out of the payload and tell devise that they are authenticated for this session.
  def sign_in_from_lti(ll)
    user = ll&.user
    if user
      sign_in user
      Rails.logger.debug("Done signing in LTI-authenticated user #{user.email}")
    elsif ll.nil?
      Rails.logger.debug("No LtiLaunch found for the given state")
    else
      Rails.logger.debug("Invalid user came through LTI launch: #{ll.request_message.inspect}")
    end
  end

end
