class LtiLinkSelectionController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :ensure_admin!
  skip_before_action :verify_authenticity_token
  
  def index
  	# There's a way to configure this. See: 
  	# https://stackoverflow.com/questions/18445782/how-to-override-x-frame-options-for-a-controller-or-action-in-rails-4
  	response.headers["X-FRAME-OPTIONS"] = "ALLOW-FROM https://braven.instructure.com"

  	@canvas_user_id = "1234test!"
  end

  def create
  end
end
