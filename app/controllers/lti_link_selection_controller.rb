class LtiLinkSelectionController < ApplicationController
  # Non-standard controller without normal CRUD methods. Disable the convenience module.
  def dry_crud_enabled?() false end

  def create
    # From assignment controller
    # params.require([:state, :lesson_content_id])
    # lti_launch = LtiLaunch.current(params[:state])
    # assignment_url = lesson_content_url(params[:lesson_content_id])
    # @deep_link_return_url, @jwt_response = helpers.lti_deep_link_response_message(lti_launch, lesson_content_url)
  end
end
