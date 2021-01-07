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

  def completed
    authorize @accelerator_survey_submission
  end

private
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

  def set_course
    @course ||= Course.find_by_canvas_course_id!(
      @lti_launch.request_message.canvas_course_id,
    )
  end

  def set_type!
    params.require(:type)
    raise NotImplementedError unless ['Pre', 'Post'].include? params[:type]
    @type = params[:type].downcase
  end
end
