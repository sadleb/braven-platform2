require 'zip'

class LessonContentsController < ApplicationController
  # FIXME: Get rid of this, something weird is going on right now
  skip_before_action :authenticate_user!
  skip_before_action :ensure_admin!
  skip_before_action :verify_authenticity_token

  def new
    @lesson_content = LessonContent.new
  end

  def create
    params.require([:state, :lesson_content_zipfile])

    lti_launch = LtiLaunch.current(params[:state])
    @lesson_content = LessonContent.new(lesson_content_params)
    @lesson_content.save

    # TODO: Extract this asynchronously
    # https://app.asana.com/0/1174274412967132/1184800386160057
    @s3_index_url = @lesson_content.extract
    lesson_url = lesson_content_url(@lesson_content)

    # TODO: Decide whether it's better to use lesson_url that does a redirect
    # https://app.asana.com/0/1174274412967132/1184800386160059
    @deep_link_return_url, @jwt_response = helpers.lti_deep_link_response_message(lti_launch, lesson_url)
  end

  def show
    lesson_content = LessonContent.find(params[:id])
    redirect_to lesson_content.get_index_url
  end

  private
  def lesson_content_params
    params.permit(:lesson_content_zipfile)
  end
end
