# frozen_string_literal: true

require 'form_assembly_api'

# We have Pre- and Post-Accelerator Surveys that Fellows respond to at the
# beginning and end of the course. These surveys are built on FormAssembly, like
# waivers (see WaiverSubmissionsController).
#
# This controller handles rendering (#new) and submitting (#create) the form
# for the survey. It allows the user to submit once and shows a "Thank You" page
# afterwards (#completed).
#
# This controller inherits from FormAssemblyController, which implements
# embedding the FormAssembly form in a view.
#
# It also includes the Submittable concern, which handles creating the
# submission on Canvas using the LTI Advantage API, as well as redirecting to
# #completed once a submission exists.
#
# In order for these surveys to work, you will need to configure the following:
#
#   - FormAssembly surveys
#     - Survey for pre-accelerator
#     - Survey for post-accelerator
#
#   - FormAssembly survey connectors (for each survey)
#     - Post Redirect: to the #create endpoint
#     - Salesforce: to write responses back to Salesforce
#
#   - Salesforce Program
#     - Highlander Accelerator Course ID: your Playground Canvas Course ID
#     - FA ID Fellow PreSurvey: FormAssembly survey for pre-accelerator ID
#     - FA ID Fellow PostSurvey: FormAssembly survey for post-accelerator ID
#
# For logic that handles publishing and unpublishing these surveys as Canvas
# Assignments, see AcceleratorSurveysController.

class AcceleratorSurveySubmissionsController < FormAssemblyController
  include DryCrud::Controllers::Nestable
  nested_resource_of Course

  # For #new, #create actions
  include Submittable

  layout 'lti_canvas'

  # For FormAssemblyController
  attr_reader :course
  before_action :set_course

  # We always do AcceleratorSurveySubmission.new to create the model instance
  # for the controller because it's an active model and not stored in the DB.
  before_action :set_new_model_instance
  before_action :set_type!
  before_action :set_up_formassembly, only: [:new]
  before_action :set_new_survey_url, only: [:launch]

  # Presents a page to launch the survey form in its own window (aka this window) instead of inside an iFrame where
  # the survey assignment is shown in Canvas.
  #
  # Note: ideally this would be nested under course similar to the rest of the routes, but it
  # means that we'd need to adjust the LtiLaunch URLs when we launch a new Program and the course id changes.
  # This way, it's just a static endpoint for any course to launch the survey for that course pulling the
  # course info out of the LtiLaunch context.
  #
  # GET /{pre,post}accelerator_survey_submissions/launch
  def launch
    authorize instance_variable

    redirect_to completed_submissions_path if previous_submission
  end

  def completed
    authorize @accelerator_survey_submission
  end

private
  # Override default Submittable behavior.
  def redirect_after_create?
    false
  end

  # For #new, embed the FormAssembly form in the view
  def set_up_formassembly
    form_id = form_assembly_info.send("#{@type}_accelerator_survey_form_id")
    if params[:tfa_next].present?
      @form_head, @form_body = FormAssemblyAPI.client
        .get_next_form_head_and_body(params[:tfa_next])
    else
      @form_head, @form_body = FormAssemblyAPI.client
        .get_form_head_and_body(form_id, participantId: form_assembly_info.participant_id)
    end
    set_up_head()
    set_up_body()
  end

  # For Submittable
  def answers_params_hash
    # Empty because we don't need to store anything in our DB.
    # FormAssembly stores the actual responses and Canvas LTI Advantage API
    # stores whether a submission has been made.
    # You will have to add Salesforce to the FormAssembly form's connectors
    # and configure it to write the data back directly to Salesforce.
    {}
  end

  # Overrides Submittable
  # We give a full-credit score to the Fellow for submitting their surveys,
  # so we can check Canvas to see whether this exists in order to determine
  # whether there's already been a submission.
  def previous_submission
    # Memoize so we don't do another network call
    @line_item ||= LtiAdvantageAPI.new(@lti_launch).get_result().present?
    # Return an instance_variable for Submittable to use with instance_path
    return @line_item ? @accelerator_survey_submission : nil
  end

  # We don't have anything saved to the DB, so we explicitly specify the 
  # parent and fetch the instance
  def parent_variable_name
    'course'
  end

  def parent_variable_instance
    @course
  end

  # We use the #completed action like WaiverSubmissionsController because
  # there's no instance to for the ID needed for the #show action.
  def instance_path(instance)
    send(
      "completed_#{@type}accelerator_survey_submissions_path",
      state: params[:state],
    )
  end

  def submission_url(instance)
    send(
      "completed_#{@type}accelerator_survey_submissions_url",
      protocol: 'https',
    )
  end

  def completed_submissions_path
    send(
      "completed_#{@type}accelerator_survey_submissions_path",
      state: @lti_launch.state
    )
  end

  def set_course
    @course ||= Course.find_by_canvas_course_id!(
      @lti_launch.request_message.canvas_course_id,
    )
  end

  def set_new_survey_url
    @new_survey_url = send(
      "new_#{@type.downcase}accelerator_survey_submission_url",
      protocol: 'https',
      state: @lti_launch.state,
    )
  end

  def set_type!
    params.require(:type)
    raise NotImplementedError unless ['Pre', 'Post'].include? params[:type]
    @type = params[:type].downcase
  end
end
