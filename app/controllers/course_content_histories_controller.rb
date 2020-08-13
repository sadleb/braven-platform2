require 'lti_advantage_api'
require 'lti_score'
require 'uri'

class CourseContentHistoriesController < ApplicationController
  include DryCrud::Controllers::Nestable
  nested_resource_of CourseContent
  layout 'content_editor'

  # TODO: Only for sessionless launches: https://app.asana.com/0/1174274412967132/1188539121871585
  skip_before_action :verify_authenticity_token, only: [:create] 

  before_action :set_course_content, only: [:index, :show, :create]

  # GET /course_contents/:id/versions
  # GET /course_contents/:id/versions.json
  def index
  end

  # GET /course_contents/:id/versions/1
  # GET /course_contents/:id/versions/1.json
  def show
    # This shows a project submission for this version of the course_contents, the one
    # associated with a project when inserted into Canvas through the LTI extension. It does this
    # by loading the HTML with user input fields (aka data-bz-retained) highlighted, disabled (readonly),
    # and populated with the student's answers when they submitted it.
    #
    # TODO: Long term, a project will use the Project model and store the snapshot of the html there or maybe have a ProjectContent
    # model to hold it. But in order to get a demo going and not deal with the complexity of filling out the whole course/org/role/project/project_submission
    # data model, we're just doing the dumb thing for now. These histories aren't currently used by any end-user.
    params.require([:user_id, :course_content_id, :state])

    # TODO: make sure the currently logged in user has access to view the submission for this user_id.
    # Must be the student themselves or a TA or staff who has access. Need to use Canvas roles to check.
    # Task: https://app.asana.com/0/1174274412967132/1185569091008475    
    @user = User.find(params[:user_id])
    launch = LtiLaunch.current(params[:state])
    @lti_auth_state =launch.state
    @project_lti_id = launch.activity_id
  end

  # TODO: https://app.asana.com/0/1174274412967132/1186960110311121
  def create
    params.require([:state, :course_content_id]) 

    submission_url = Addressable::URI.parse(course_content_course_content_history_url(
      @course_content,
      @course_content.last_version,
    ))
    submission_url.query = { user_id: current_user.id }.to_query

    lti_launch = LtiLaunch.current(params[:state])
    lti_score = LtiScore.new_project_submission(current_user.canvas_id, submission_url.to_s)
    LtiAdvantageAPI.new(lti_launch).create_score(lti_score)
  end

  private

    def set_course_content
      @course_content = CourseContent.find(params[:course_content_id])
    end
end
