# We have two main entry points for the Braven apps, either Canvas or
# the Platform. The Platform is only meant for staff (aka admin role)
# and Canvas is meant for everyone else. Since we don't know who the user
# is until after they sign-in, anyone who ends up trying to sign-in to
# a platform page who isn't staff should be sent to Canvas instead.
#
# This works by changing the Devise route for the cas_sessions controller
# to point at this subclass so we can override what we need to.
#
# Note: there is similar redirect logic that uses CasHelper#default_service_url_for(user)
# which is slighty different from this. This is the final target path we send them
# to after login while that is to decide the CAS service that should handle SSO
# ticket negotiation. This controller ONLY APPLIES when trying to access a Platform page.
# This means that f you came from Canvas or use a Canvas SSO login service, the CAS SSO
# stuff will send you back to Canvas without hitting this.
class Users::CasSessionsController < Devise::CasSessionsController

  def after_sign_in_path_for(user)
    (user.admin? ? root_path : canvas_url)
  end

end
