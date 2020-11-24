# frozen_string_literal: true

require 'form_assembly_api'
require 'lti_score'
require 'lti_advantage_api'

# Handles launching and submitting waivers that we require folks to sign in order to participate
# in the course. See WaiversController for more info about how these are published and how they're
# created and configured (FormAssembly).
class WaiverSubmissionsController < ApplicationController
  include LtiHelper
  include Rails.application.routes.url_helpers

  layout 'form_assembly'

  before_action :set_lti_launch, only: [:new, :create, :launch]
  before_action :set_base_course, only: [:new, :create, :launch]
  before_action :set_new_waivers_url, only: [:launch]

  skip_before_action :verify_authenticity_token, only: [:create], if: :is_sessionless_lti_launch?

  # The FormAssembly Javascript does an eval() so we need to loosen the CSP.
  # 
  # This syntax took forever to get right b/c content_security_policy is a DSL and you can't just
  # append normal items to an existing array. An alternative if we need to do this
  # sort of thing widely is https://github.com/github/secure_headers which has named overrides.
  content_security_policy do |policy|
     global_script_src =  policy.script_src
     policy.script_src "#{Rails.application.secrets.form_assembly_url}:*", :unsafe_eval, -> { global_script_src }
  end

  # Presents a page to launch the Waivers form in its own window (aka this window) instead of inside an iFrame where
  # the Waivers assignment is shown in Canvas.
  #
  # Note: ideally this would be nested under base_course similar to the rest of the routes, but it
  # means that we'd need to adjust the LtiLaunch URLs when we launch a new Program and the course id changes.
  # This way, it's just a static endpoint for any course to launch the waivers for that course pulling the
  # course info out of the LtiLaunch context.
  #
  # GET /waivers/launch
  def launch
    authorize :waiver_submissions

    redirect_to completed_waiver_submissions_path if waivers_already_signed?
  end

  # Show the FormAssembly waiver form for them to sign.
  #
  # GET /waivers/new
  def new 
    authorize :waiver_submissions

    # We just show a message about the Waivers only being loaded for a launched Course.
    return if @base_course.is_a?(CourseTemplate)

    if params[:tfa_next].present?
      @form_head, @form_body = FormAssemblyAPI.client
        .get_next_form_head_and_body(params[:tfa_next])
    else
      @form_head, @form_body = FormAssemblyAPI.client
        .get_form_head_and_body(form_assembly_info.waivers_form_id, participantId: form_assembly_info.participant_id)
    end

    setup_head()
    setup_body()
  end

  # Handle the submission of the FormAssembly waivers. This is configured in FormAssembly by
  # creating a "Post Redirect" Connector on the final form in the flow when the Waivers are considered
  # fully signed. Under where the Connector says:
  #     "Posts submitted data back to a third-party script. Users are redirected to this script."
  # Add the URL for this action in the "Remote Script" field.
  #
  # See: https://help.formassembly.com/help/post-redirect-connector
  #
  # POST /waivers
  def create
    authorize :waiver_submissions

    # Create a submission for this assignment in Canvas. This is required to to have the 
    # Pre-Requisites module satisfy its completion requirements in order to unlock
    # access to the rest of the Canvas modules.
    lti_score = LtiScore.new_full_credit_submission(
      current_user.canvas_user_id,
      completed_waiver_submissions_url(protocol: 'https'),
    )
    lti_advantage_api_client.create_score(lti_score)
  end

  # Shows a "thank you for submitting" page. Note that since there is no
  # local waiver's model, we use completed instead of show b/c it's a static endpoint with
  # no id.
  # GET /waivers/completed
  def completed
    authorize :waiver_submissions
  end

private

  # The Referrer-Policy is "strict-origin-when-cross-origin" by default which causes
  # the fullpath to not be sent in the Referer header when the Submit button is clicked.
  # This leads to Form Assembly not knowing where to re-direct back to for forms with multiple
  # pages (e.g. for one with an e-signature). Loosen the policy so the whole referrer is sent.
  def setup_head
    @form_head.insert(0, '<meta name="referrer" content="no-referrer-when-downgrade">')
  end

  # Insert an <input> element that will submit the state with the form so that it works in
  # browsers that don't have access to session and need to authenticate using that.
  #
  # Note: I tried setting this up on the FormAssembly side of things, but you can't control the
  # names of the fields that you can pre-populate things when loading the form. They are things like
  # "tfa_26" depending on how many and what order you add fields. See:
  # https://help.formassembly.com/help/prefill-through-the-url
  #
  # TODO: if you try to go Back in the browser after submitting the final e-signature review
  # form, the call to the FormAssembly API with that tfa_next param returns an empty body and this 
  # throws an exception. Do something more graceful: https://app.asana.com/0/1174274412967132/1199231117515065
  def setup_body
    doc = Nokogiri::HTML::DocumentFragment.parse(@form_body)
    form_node = doc.at_css('form')
    form_node.add_child('<input type="hidden" value="' + html_safe_state + '" name="state" id="state">')
    @form_body = doc.to_html
  end

  # This needs to be safe to inject in HTML and not expose an XSS vulnerability.
  # Reading it from the @lti_launch is safe since we generate that, but reading it
  # from a query param is not safe.
  def html_safe_state
    @lti_launch.state
  end

  def set_base_course
    @base_course = BaseCourse.find_by_canvas_course_id!(@lti_launch.request_message.canvas_course_id)
  end

  def set_new_waivers_url
    @new_waivers_url = "https://#{Rails.application.secrets.application_host}#{new_waiver_submission_path}?state=#{@lti_launch.state}"
  end

  def waivers_already_signed?
    lti_advantage_api_client.get_result().present?
  end

  def form_assembly_info
    @form_assembly_info ||= FetchSalesforceFormAssemblyInfo.new(@base_course.canvas_course_id, current_user).run
  end

  def lti_advantage_api_client
    @lti_advantage_api_client ||= LtiAdvantageAPI.new(@lti_launch)
  end
end
