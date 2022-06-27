# frozen_string_literal: true

require 'form_assembly_api'
require 'lti_score'
require 'lti_advantage_api'

# Handles launching and submitting forms that we require folks to sign in order to participate
# in the course. See FormsController for more info about how these are published and how they're
# created and configured (FormAssembly).
class FormSubmissionsController < FormAssemblyController
  include Rails.application.routes.url_helpers

  attr_reader :course, :lti_launch

  before_action :set_lti_launch, only: [:new, :create, :launch]
  before_action :set_course, only: [:new, :create, :launch]
  before_action :set_new_forms_url, only: [:launch]

  # Presents a page to launch Forms in its own window (aka this window) instead of inside an iFrame where
  # the Forms assignment is shown in Canvas.
  #
  # Note: ideally this would be nested under course similar to the rest of the routes, but it
  # means that we'd need to adjust the LtiLaunch URLs when we launch a new Program and the course id changes.
  # This way, it's just a static endpoint for any course to launch the forms for that course pulling the
  # course info out of the LtiLaunch context.
  #
  # GET /form_submissions/launch
  def launch
    authorize @course, policy_class: FormSubmissionPolicy

    redirect_to completed_form_submissions_path(lti_launch_id: params[:lti_launch_id]) and return if forms_already_signed?

    render layout: 'lti_canvas'
  end

  # Show the FormAssembly form for them to sign.
  #
  # GET /form_submissions/new
  def new
    authorize :form_submission

    if params[:tfa_next].present?
      @form_head, @form_body = FormAssemblyAPI.client
        .get_next_form_head_and_body(params[:tfa_next])
    else
      @form_head, @form_body = FormAssemblyAPI.client
        .get_form_head_and_body(form_assembly_info.forms_form_id, participantId: form_assembly_info.participant_id)
    end

    set_up_head()
    set_up_body()
  end

  # Handle the submission of the FormAssembly forms. This is configured in FormAssembly by
  # creating a "Post Redirect" Connector on the final form in the flow when the Forms are considered
  # fully signed. Under where the Connector says:
  #     "Posts submitted data back to a third-party script. Users are redirected to this script."
  # Add the URL for this action in the "Remote Script" field.
  #
  # See: https://help.formassembly.com/help/post-redirect-connector
  #
  # POST /form_submissions
  def create
    authorize :form_submission

    # Create a submission for this assignment in Canvas. This is required to to have the
    # Pre-Requisites module satisfy its completion requirements in order to unlock
    # access to the rest of the Canvas modules.
    lti_score = LtiScore.new_full_credit_submission(
      current_user.canvas_user_id,
      completed_form_submissions_url(protocol: 'https'),
    )
    lti_advantage_api_client.create_score(lti_score)

    render layout: 'lti_canvas'
  end

  # Shows a "thank you for submitting" page. Note that since there is no
  # local form's model, we use completed instead of show b/c it's a static endpoint with
  # no id.
  # GET /form_submissions/completed
  def completed
    authorize :form_submission
    render layout: 'lti_canvas'
  end

private

  def set_course
    @course = Course.find_by_canvas_course_id!(@lti_launch.request_message.canvas_course_id)
  end

  def set_new_forms_url
    @new_forms_url = new_form_submission_url(lti_launch_id: @lti_launch.id)
  end

  def forms_already_signed?
    lti_advantage_api_client.get_result().has_full_credit?
  end

  def lti_advantage_api_client
    @lti_advantage_api_client ||= LtiAdvantageAPI.new(@lti_launch)
  end
end
