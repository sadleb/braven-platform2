# Patches devise_cas_authenticable to allow redirecting to https://braven.instructure.com
# when doing it's SSO logic.
#
# Refs:
# * https://github.com/nbudin/devise_cas_authenticatable/commit/5ba24157d416def1a9b0f8d97d9bb5c09d9cf85a

require 'devise/sessions_controller'
require 'devise/cas_sessions_controller'

class Devise::CasSessionsController < Devise::SessionsController

  # Redefines the original method at the below link to use allow_other_host:
  # https://github.com/nbudin/devise_cas_authenticatable/blob/v1.10.4/app/controllers/devise/cas_sessions_controller.rb#L19
  def service
    redirect_to after_sign_in_path_for(warden.authenticate!(:scope => resource_name)), allow_other_host: true
  end
end