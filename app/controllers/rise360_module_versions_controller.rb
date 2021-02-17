# frozen_string_literal: true

class Rise360ModuleVersionsController < ApplicationController
  include LtiHelper

  layout 'lti_canvas'

  before_action :set_lti_launch, only: [:show]

  # This the LTI launch URL used for Canvas assignments that are Modules.
  # It is similar to CourseResourcesController#lti_show because both
  # CourseResource and Rise360{Version} are backed by Articulate Rise360
  # packages attached to rise360_zipfile on the model.
  # There is nothing here that ties this to the Course that the Module is in.
  # Eventually, we'll use an endpoint on CourseRise360ModuleVersionsController
  # to render this content.
  # TODO: Convert this to use a static endpoint for LTI launch
  # https://app.asana.com/0/1174274412967132/1199352155608256 
  def show
    authorize Rise360ModuleVersion
    @rise360_module_version = Rise360ModuleVersion.find(params[:id])
    url = Addressable::URI.parse(@rise360_module_version.launch_url)
    url.query_values = helpers.launch_query
    @launch_path = "#{url.path}?#{url.query}"
  end
end
