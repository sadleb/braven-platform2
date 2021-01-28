# We have two main entry points for the Braven apps, either Canvas or
# the Platform. The Platform is only meant for staff (aka admin role)
# and Canvas is meant for everyone else. Since we don't know who the user
# is until after they sign-in, anyone who ends up trying to sign-in to
# a platform page who isn't staff should be sent to Canvas instead.
#
# This works by changing the Devise route for the cas_sessions controller
# to point at this subclass so we can override what we need to.
class Users::CasSessionsController < Devise::CasSessionsController

  def after_sign_in_path_for(user)
    (user.admin? ? root_path : canvas_url)
  end

end
