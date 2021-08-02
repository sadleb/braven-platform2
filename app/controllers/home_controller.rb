class HomeController < ApplicationController
  layout 'admin'

  def welcome
    authorize :application, :index?
  end

  # We want random routes on our server to return a 401 unauthorized for JSON
  # requests and redirect to the login page for others. If you're already logged
  # in, return a 404 as expected.
  # This is so that bots can't enumerate paths and objects on our server.
  # Force an actual person to go to github to find that out!
  def missing_route
    authorize :application, :index?

    # It's nice to get that page that shows all the routes in dev.
    if Rails.env.development? && Rails.application.config.consider_all_requests_local
      raise ActionController::RoutingError, "No route matches path /#{params[:other]}"
    end

    render plain: '404 Not Found', status: 404
  end
end
