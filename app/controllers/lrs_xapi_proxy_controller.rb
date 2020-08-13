require "lrs_xapi_proxy"

class LrsXapiProxyController < ApplicationController
  skip_before_action :verify_authenticity_token

  # Non-standard controller without normal CRUD methods. Disable the convenience module.
  def dry_crud_enabled?() false end

  def xAPI
    # TODO: Make sure current_user is allowed to view user_override's stuff.
    # https://app.asana.com/0/1174274412967132/1185569091008475/f
    #
    # A user_override is used when say a Teaching Assistant is viewing a project
    # submission for a Student/Fellow. The current_user would be the TA but we really
    # want to be querying the LRS as the Student.
    user = params[:user_override] ? User.find(params[:user_override]) : current_user
    response = LrsXapiProxy.request(request, request.params['endpoint'], user)

    render json: response.body, status: response.code
  end
end
