class CustomContentVersionsController < ApplicationController
  include LtiHelper
  include DryCrud::Controllers::Nestable

  nested_resource_of CustomContent
  layout 'content_editor'

  before_action :set_lti_launch, only: [:show]

  # GET /custom_contents/:id/versions
  # GET /custom_contents/:id/versions.json
  def index
    authorize custom_content_version_class
    # Overwrite the object automatically created because the parameter for the
    # CustomContent ID depends on the path name. 
    @custom_content_versions = CustomContent.find(set_custom_content_id).versions
  end

  # GET /custom_contents/:id/versions/1
  # GET /custom_contents/:id/versions/1.json
  def show
    authorize @custom_content_version
  end

  private
  def set_custom_content_id
    case params[:type]
    when 'ProjectVersion'
      params[:project_id]
    when 'SurveyVersion'
      params[:survey_id]
    when nil
      params[:custom_content_id]
    else
      raise TypeError.new "Unknown CustomContentVersion type: #{params[:type]}"
    end
  end

  # Don't use `params[:type]` without sanitizing it first
  def custom_content_version_class
    case params[:type]
    when nil
      CustomContentVersion
    when 'ProjectVersion'
      ProjectVersion
    when 'SurveyVersion'
      SurveyVersion
    else
      raise TypeError.new "Unknown CustomContentVersion type: #{type}"
    end
  end
end
