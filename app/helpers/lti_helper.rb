require 'lti_deep_linking_response_message'
require 'lti_deep_linking_request_message'
require 'lrs_xapi_mock'

module LtiHelper

  USERNAME_PLACEHOLDER = "RISE360_USERNAME_REPLACE"
  PASSWORD_PLACEHOLDER = "RISE360_PASSWORD_REPLACE"

  def lti_deep_link_response_message(lti_launch, content_items_url)
    client_id = lti_launch.auth_params[:client_id]
    deep_link = LtiDeepLinkingRequestMessage.new(lti_launch.id_token_payload)
    response_msg = LtiDeepLinkingResponseMessage.new(client_id, deep_link.deployment_id)
    response_msg.addIFrame(content_items_url)
    jwt_response = Keypair.jwt_encode(response_msg.to_h)

    [deep_link.deep_link_return_url, jwt_response]
  end

  def set_lti_launch
    return if @lti_launch
    @lti_launch = LtiLaunch.current(params[:state]) if params[:state]
  end

  def is_sessionless_lti_launch?
    set_lti_launch
    (@lti_launch ? @lti_launch.sessionless? : false )
  end

  # Helps configure Rise 360 module to be able to send xAPI statements to
  # our mock Learning Record Store (LRS).
  #
  # Note: The endpoint for the LRS is set to the LRS_PATH on this server and
  # requests are mocked as though we are an actual LRS using LrsXapiMock.
  #
  # See:
  # - https://articulate.com/support/article/Implementing-Tin-Can-API-to-Support-Articulate-Content#launching-public-content
  # - https://xapi.com/try-developer/
  # - https://learningpool.com/how-to-launch-elearning-content-using-xapi/

  # TODO: we can also provide an activity_id and registration. These are ways to group xApi statements together.
  # I'm thinking each lesson or project has an activity_id to group the statements for that and then we have a
  # registration for the course to get all statements for a user for a particular course (in case they take multiple or drop and try again).
  # However, will we need a finer grained level to group statements than just project / lesson?
  def launch_query
    lrs_mock_url = URI(root_url)
    lrs_mock_url.path = LrsXapiMock::LRS_PATH
    {
      :endpoint => lrs_mock_url.to_s,
      :auth => "#{LtiAuthentication::LTI_AUTH_HEADER_PREFIX} #{params[:state]}",
      # Our LRS mock will ignore these, but Rise 360 modules complain if they're not set.
      # Send empty values to get the Rise 360 Tincan code won't error out on missing keys.
      :actor => '{"name":"'"#{USERNAME_PLACEHOLDER}"'", "mbox":["mailto:'"#{PASSWORD_PLACEHOLDER}"'"]}',
      # Note: in case you try to set the activity_id through the launch params, it doesn't work. Rise360 packages
      # set it to whatever was specified when you exported the package. We should use their IDs but we need to coordinate
      # with designers on what to do here b/c we have the potential to be inconsistent making the data hard to gather.
      # Actually, this means a single export that is imported into different courses needs the registration set so we can
      # pull data for that lesson just for the current course and not just any course.
      # ALSO, we *could* set the activity id either when we publish it or on the fly by changing the
      # TC_COURSE_ID variable in tc-config.js
      # ALSO note that the "experienced" statement send the activity ID appended with another ID to identify the section
      # of the lesson. The IDs are defined in tincan.xml. See here for an example:
      # https://platform-dev-file-uploads.s3.amazonaws.com/lessons/ytec17h3ckbr92vcf7nklxmat4tc/tincan.xml
      #      :activity_id => url_encode('https://braven.instructure.com/courses/48/assignments/158')

    }
  end
end
