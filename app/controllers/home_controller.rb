class HomeController < ApplicationController
  layout 'admin'

  def welcome
    authorize :application, :index?
  end

  # We want random routes on our server to return a 401 unauthorized for JSON
  # requests and redirect to the login page for others. If you're already logged
  # in, then redirect to the normal homepage,
  # This is so that bots can't enumerate paths and objects on our server.
  # Force an actual person to go to github to find that out!
  def missing_route
    authorize :application, :index?
    # It's nice to get that page that shows all the routes in dev.
    raise ActionController::RoutingError, "No route matches path /#{params[:other]}" if Rails.env.development?
    redirect_to home_welcome_path
  end
end
