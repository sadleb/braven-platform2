require 'rubycas-server-core/tickets'
require 'dry_crud'

class ApplicationController < ActionController::Base
  include RubyCAS::Server::Core::Tickets
  include DryCrud::Controllers

  before_action :authenticate_user!
  before_action :ensure_admin!

  private
  
  def authenticate_user!
    super unless authorized_by_token? || cas_ticket?
  end

 
  # TODO: need to change this to only be for access to admin stuff. E.g. for non-admins, we may
  # want to see if they have a Portal account and redirect there.
  def ensure_admin!
    if current_user
      redirect_to('/unauthorized') unless current_user.admin?
    end
  end
  
  def authorized_by_token?
    return false unless request.format.symbol == :json

    key = params[:access_key] || request.headers['Access-Key']
    return false if key.nil?
    
    !!AccessToken.find_by(key: key)
  end

  def cas_ticket?
    ticket = params[:ticket]
    return false if ticket.nil?

    ServiceTicket.exists?(ticket: ticket)
  end

  # This is defined by :database_authenticable on the User model, but we're using :cas_authenticatable
  # However, we still want to support account creation, registration, and confirmation which is 
  # database_authenticable functionality so we need to define this for those built-in views to work.
  def new_session_path(scope)
    new_user_session_path
  end
  helper_method :new_session_path

end
