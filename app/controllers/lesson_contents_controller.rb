require 'zip'

class LessonContentsController < ApplicationController
  # FIXME: Get rid of this, something weird is going on right now
  skip_before_action :authenticate_user!
  skip_before_action :ensure_admin!
  skip_before_action :verify_authenticity_token

  def new
  end

  def create
    # TODO: Should we make state optional, e.g. allow creating lessons contents
    # outside of Canvas's LTI link extension?
    # https://app.asana.com/0/1174274412967132/1184800386160070
    params.require([:state, :lesson_content_zipfile])
    lti_launch = LtiLaunch.current(params[:state])

    @lesson_content = LessonContent.new(lesson_content_create_params)
    @lesson_content.save!

    # TODO: Extract this asynchronously
    # https://app.asana.com/0/1174274412967132/1184800386160057
    @lesson_content.publish

    lesson_url = lesson_content_url(@lesson_content)

    @deep_link_return_url, @jwt_response = helpers.lti_deep_link_response_message(lti_launch, lesson_url)
  end

  def show
    redirect_to @lesson_content.launch_url
  end

  private
  def lesson_content_create_params
    params.permit(:lesson_content_zipfile)
  end
end
