# frozen_string_literal: true

require 'rubycas-server-core/util'
require 'rubycas-server-core/tickets'
require 'rubycas-server-core/tickets/validations'
require 'rubycas-server-core/tickets/generations'

# IMPORTANT: this controller is complicated, ugly, and handles a ton of permutations
# of tricky stuff. A new dev or someone that hasn't spent a LOT of time going through
# all the various registration, confirmation, password reset, account creation / mgmt
# features should AVOID working on this. You're very likely to expose security vulnerabilities.
# Try to push back on whoever is very nicely asking for some seemingly simple enhancement to
# make it easier to log in and tell them it's dangerous without spending a ton of time
# getting up to speed. We spent about a month getting this all working in a way that we
# think helps get folks access to their account without opening a support ticket AND
# also doesn't expose security issues that a bad-actor could use to exploit our systems.

class CasController < ApplicationController
  layout 'accounts'
  skip_before_action :authenticate_user!
  # Skip the verify_authorized callback for this controller, since we won't be logged in
  # and thus get no benefit from authorization.
  skip_after_action :verify_authorized

  # Skip the add_honeycomb_fields callback for this controller, since we won't be logged in
  # and it tries to add information about the currently logged in user. Note: if you don't
  # skip this, just the act of checking current_user or user_signed_in? causes the CAS
  # validation to happen a second time which conflicts with our feature specs
  # and these that use VCR with only 1 interaction recorded. I spent too long troubleshooting
  # that before just adding this line.
  skip_before_action :add_honeycomb_fields

  before_action :set_settings
  before_action :set_request_client
  before_action :set_params
  before_action :set_loginpost_params, only: [:loginpost]

  # Note that the following helper classes in this controller come from this module
  # TGT = Ticket Granting Ticket
  # ST = Service Ticket
  # LT = Login Ticket
  # PGT = Proxy Granting Ticket
  # PT = Proxy Ticket
  include RubyCAS::Server::Core::Tickets

  GENERIC_LOGIN_FAILED_ERROR_MESSAGE = { :type => 'mistake', :message => 'Incorrect username or password.' }

  def login
    # make sure there's no caching
    request.headers['Pragma'] = 'no-cache'
    request.headers['Cache-Control'] = 'no-store'
    request.headers['Expires'] = (Time.now - 1.year).rfc2822

    # optional params
    @gateway = params['gateway'] == 'true' || params['gateway'] == '1'
    @message = { :type => 'notice', :message => params[:notice] } if params[:notice]

    if tgc = request.cookies['tgt']
      tgt, tgt_error = TGT.validate(tgc)
    end

    if tgt && !tgt_error
      # Already signed in but hitting the /cas/login path directly. Ideally, we would redirect them
      # to the proper place using something like the following, but the current_user isn't set as part
      # of this CAS stuff which we'd also ideally do, but I don't want to get deep into the CAS stuff
      # so I'm leaving the current behavior in for now.
      # redirect_to after_sign_in_path_for(current_user) and return

      @message = {
        :type => 'notice',
        :message => "You are currently logged in as '#{tgt.username}'. If this is not you, please log in below."
      }
    elsif tgt_error
      logger.debug('Ticket granting cookie could not be validated. Most likely it is not in the database')
    elsif !tgt
      logger.debug('No ticket granting ticket detected.')
    end

    if params['redirection_loop_intercepted']
      @message = {
        :type => 'mistake',
        :message => 'The client and server are unable to negotiate authentication. Please try logging in again later.'
      }
    end

    begin
      if @service
        if @renew
          logger.info("Authentication renew explicitly requested. Proceeding with CAS login for service #{@service.inspect}.")
        elsif tgt && !tgt_error
          logger.debug('Valid ticket granting ticket detected.')
          st = ST.create! @service, tgt.username, tgt, @request_client
          logger.info("User '#{tgt.username}' authenticated based on ticket granting cookie. Redirecting to service '#{@service}'.")
          # Devise tends to flash a "You need to sign in or sign up before continuing." alert.
          flash.delete(:alert)
          redirect_to Utils.build_ticketed_url(@service, st) and return
        elsif @gateway
          logger.info("Redirecting unauthenticated gateway request to service '#{@service}'.")
          return redirect_to @service, status: 303
        else
          logger.info("Proceeding with CAS login for service #{@service.inspect}.")
        end
      elsif @gateway
          logger.error('This is a gateway request but no service parameter was given!')
          @message = {
            :type => 'mistake',
            :message => 'The server cannot fulfill this gateway request because no service parameter was given.'
          }
      else
        logger.info('Proceeding with CAS login without a target service.')
      end
    rescue URI::InvalidURIError
      logger.error("The service '#{@service}' is not a valid URI!")
      @message = {:type => 'mistake',
        :message => 'The target service your browser supplied appears to be invalid. Please contact your system administrator for help.'
      }
    end

    lt = LT.create! @request_client

    logger.debug("Rendering login form with login ticket for service: #{@service}, renew: #{@renew}, gateway: #{@gateway}")

    @lt = lt.ticket

    render :login
  end

  def loginpost
    if !result = LT.validate(@lt)
      @message = {:type => 'mistake', :message => error}
      # generate another login ticket to allow for re-submitting the form
      @lt = LT.create!(@request_client).ticket
      return render :login, status: :unauthorized
    end

    # generate another login ticket to allow for re-submitting the form after a post
    @lt = LT.create!(@request_client).ticket

    # Don't log out the entire @settings variable, it has sensitive info.
    logger.debug("Logging in with username: #{@username} using a login ticket for service: #{@service}")
    Honeycomb.add_field('cas_controller.username', @username)

    credentials_are_valid = false
    credentials = {
      :username => @username,
      :password => @password,
      :service => @service,
      :request => request.env
    }
    extra_attributes = {}
    successful_authenticator = nil
    last_failed_authenticator = nil
    begin
      @settings[:auth].each do |auth_class, auth_index|
        auth = auth_class.new

        auth_config = @settings[:authenticator]
        # pass the authenticator index to the configuration hash in case the authenticator needs to know
        # it splace in the authenticator queue
        auth.configure(auth_config.merge('auth_index' => auth_index))

        credentials_are_valid = auth.validate(credentials)
        if credentials_are_valid
          extra_attributes.merge!(auth.extra_attributes) unless auth.extra_attributes.blank?
          successful_authenticator = auth
          break
        else
          # DANGER!! See where this is used below to allow a very special flow to see a page that requires log in.
          last_failed_authenticator = auth
        end
      end
      Honeycomb.add_field('cas_controller.valid_credentials?', credentials_are_valid)

      if credentials_are_valid
        user = successful_authenticator.user
        add_honeycomb_context(user)
        logger.info("Credentials for username '#{@username}' successfully validated using #{successful_authenticator.class.name}.")
        logger.debug("Authenticator provided additional user attributes: #{extra_attributes.inspect}") unless extra_attributes.blank?

        tgt = TGT.create! @username, @request_client, false, extra_attributes
        response.set_cookie('tgt', tgt.to_s)
        logger.debug("Ticket granting cookie granted to #{@username.inspect}")

        Honeycomb.add_field('cas_controller.service_param_blank?', @service.blank?)
        if @service.blank?
          @service = helpers.default_service_url_for(user)
          logger.info("No service param was given, setting it to default for this user: #{@service}.")
        end

        Honeycomb.add_field('cas_controller.service', @service)
        @st = ST.create! @service, @username, tgt, @request_client
        begin
          logger.info("Redirecting authenticated user '#{@username}' at '#{@st.client_hostname}' to service '#{@service}'")
          # Devise tends to flash a "You need to sign in or sign up before continuing." alert.
          flash.delete(:alert)
          redirect_to Utils.build_ticketed_url(@service, @st) and return
        rescue URI::InvalidURIError
          logger.error("The service '#{@service}' is not a valid URI!")
          @message = {
            :type => 'mistake',
            :message => 'The target service your browser supplied appears to be invalid. Please contact your system administrator for help.'
          }
        end

      # DANGER!! The username/password is correct, but something else is making
      # this account currently invalid for login. Note that this could be a valid
      # username/password for an unconfirmed email. Be careful here!
      #
      # This works for our custom CAS authenticator, but probably
      # won't work for other auth methods! If we change auth methods, revisit.
      # PLEASE, see the note at the top of this controller about doing everything possible to avoid
      # making changes to this controller and the below behavior unless you REALLY know what
      # you're doing and have through through all the ways a bad actor could try and exploit
      # whatever enhancement you're trying to make to get access to our systems.
      elsif (
              last_failed_authenticator.respond_to?(:valid_password?) &&
              last_failed_authenticator.valid_password?(credentials)
            ) or (
              last_failed_authenticator.respond_to?(:valid_password_for_unconfirmed_email?) &&
              last_failed_authenticator.valid_password_for_unconfirmed_email?(credentials)
            )

        user = last_failed_authenticator.user
        add_honeycomb_context(user)

        if user.present? && user.registered? &&
           (!user.confirmed? || user.unconfirmed_email == @username)
          # The account is fully registered, but UNCONFIRMED.
          # Give them a button to re-send the confirm email.
          Honeycomb.add_field('cas_controller.valid_credentials?', true)
          logger.warn("Unconfirmed user tried to log in: '#{@username}'")
          redirect_to users_registration_path(uuid: user.uuid, login_attempt: true) and return
        else
          # Something else is wrong. Act as if credentials are not valid.
          logger.warn("Invalid account for user '#{@username}'")

          # Make sure the message/render here always match the ones in the `else` below this
          # so that a bad-actor can't use this behavior to determine if they have found valid credentials
          @message = GENERIC_LOGIN_FAILED_ERROR_MESSAGE
          return render :login, status: :unauthorized
        end

      # Credentials not valid.
      else
        add_honeycomb_context(last_failed_authenticator.user)
        logger.warn("Invalid credentials given for user '#{@username}'")

        # This message/render MUST match the one in the above `else` for security purposes
        @message = GENERIC_LOGIN_FAILED_ERROR_MESSAGE
        return render :login, status: :unauthorized
      end

    rescue RubyCAS::Server::Core::AuthenticatorError => e
      logger.error(e)
      Honeycomb.add_field('error', e.class.name)
      Honeycomb.add_field('error_detail', e.message)
      Honeycomb.add_field('alert.cas_controller.login_failed', true)
      Sentry.capture_exception(e)
      # generate another login ticket to allow for re-submitting the form
      @lt = LT.create!(@request_client).ticket
      @message = {:type => 'mistake', :message => e.to_s}
      return render :login , status: :unauthorized
    end

    render :login
  end

  def logout
    # The behaviour here is somewhat non-standard. Rather than showing just a blank
    # "logout" page, we take the user back to the login page with a "you have been logged out"
    # message, allowing for an opportunity to immediately log back in. This makes it
    # easier for the user to log out and log in as someone else.

    # BZ modification: always use default service so logout/login goes back to our main
    # site (which can redirect) regardless of where they came from
    @service = @service || Utils.clean_service_url(@settings[:default_service])

    @gateway = params['gateway'] == 'true' || params['gateway'] == '1'

    tgt = TicketGrantingTicket.find_by({ticket: request.cookies['tgt'],})
    response.delete_cookie 'tgt'

    if tgt
      TicketGrantingTicket.transaction do
        logger.debug("Deleting Service/Proxy Tickets for user '#{tgt.username}'")
        tgt.service_tickets.each do |st|
          ST.send_logout_notification_for_service_ticket(st) if @settings[:enable_single_sign_out]
          logger.debug "Deleting #{st.class.name.demodulize} for service #{st.service}."
          st.destroy
        end

        # TODO: Figure out how to grab all the tickets with rubycas activerecord
        # pgts = ProxyGrantingTicket.find(:all,
        #   :conditions => [ServiceTicket.quoted_table_name+".username = ?", tgt.username],
        #   :include => :service_ticket
        # )
        # pgts.each do |pgt|
        #   logger.debug("Deleting Proxy-Granting Ticket for user '#{pgt.service_ticket.username}'")
        #   pgt.destroy
        # end

        logger.debug("Deleting #{tgt.class.name.demodulize} for user '#{tgt.username}'")
        tgt.destroy
      end

      logger.info("User '#{tgt.username}' logged out.")
    else
      logger.warn('User tried to log out without a valid ticket-granting ticket.')
    end

    @message = {:type => 'confirmation', :message => 'You have successfully logged out.'}

    @lt = LT.create! @request_client

    if current_user
      sign_out_and_redirect(current_user) and return
    end
    render :login
  end

  def loginTicket
    logger.error('Tried to use login ticket dispenser with get method!')
    render :json => {:response => 'To generate a login ticket, you must make a POST request.'}, status: :unprocessable_entity
  end

  # Renders a page with a login ticket (and only the login ticket)
  # in the response body.
  def loginTicketPost
    lt = LT.create! @request_client

    logger.debug("Dispensing login ticket to host #{@request_client.inspect}")

    render :json => {:ticket => lt.ticket}
  end

  def validate
    st, @error = ST.validate(@service, @ticket)

    return render json: {error: @error}, status: :unprocessable_entity if @error

    @success = !st.nil? && !@error
    @username = st.username if @success
    Honeycomb.add_field_to_trace('user.email', @username)

    render(json: {success: @success, user: @username})
  end

  def serviceValidate
    @pgt_url = params['pgtUrl']

    st, @error = ST.validate(@service, @ticket)
    @success = !st.nil? && !@error

    if @success
      @username = st.username
      Honeycomb.add_field_to_trace('user.email', @username)
      if @pgt_url
        pgt = PGT.create @pgt_url, st, @request_client
        @pgtiou = pgt.iou if pgt
      end
      tgt = TGT.find_by(id: st.ticket_granting_ticket_id)
      @extra_attributes = JSON.parse(tgt.extra_attributes) if tgt
    end

    render :service_validate, formats: [:xml]
  end

  def proxyValidate
    @pgt_url = params['pgtUrl']

    pt, @error = PT.validate(@service, @ticket)

    @success = !pt.nil? && !@error
    @proxies = []
    if @success
      @username = pt.username
      Honeycomb.add_field_to_trace('user.email', @username)

      if pt.kind_of? ProxyTicket
        st = ST.find_by(id: pt.service_ticket_id)
        tgt = TGT.find_by(id: st.ticket_granting_ticket_id)
        @proxies << st.service if st
        @extra_attributes = JSON.parse(tgt.extra_attributes) if tgt
      end

      if @pgt_url
        pgt = PGT.create @pgt_url, pt, @request_client
        @pgtiou = pgt.iou if pgt
      end
    end

    render :proxy_validate, formats: [:xml]
  end

  def proxy
    @ticket = params['pgt']
    @target_service = params['targetService']

    pgt, @error = PGT.validate(@ticket)

    @success = !pgt.nil? && !@error
    @pt = PT.create! @target_service, pgt, @request_client if @success

    render :proxy, formats: [:xml]
  end

  class PGT
    include RubyCAS::Server::Core::Tickets::Validations
  end

private

  def set_request_client
    @request_client = request.env['HTTP_X_FORWARDED_FOR'] || request.env['REMOTE_HOST'] || request.env['REMOTE_ADDR']
  end

  def set_settings
    @settings = RubyCAS::Server::Core::Settings._settings
  end

  def set_params
    safe_service_param = helpers.safe_service_url(params['service'])
    @service = Utils.clean_service_url(safe_service_param) if safe_service_param
    @ticket = params['ticket'] || nil
    @renew = params['renew'] || nil
    @extra_attributes = {}
  end

  def set_loginpost_params
    if params[:username]
      @username = params[:username].downcase.strip
      Honeycomb.add_field_to_trace('user.email', @username)
    end
    @password = params[:password]
    @lt = params[:lt]
  end

  def add_honeycomb_context(user)
    Honeycomb.add_field('user.present?', user.present?)
    user&.add_to_honeycomb_trace()
  end
end

# TODO: move this to the rubycas-server-core gem here:
# lib/rubycas-server-core/tickets.rb
module RubyCAS
  module Server
    module Core
      module Tickets
        class PGT
          extend ::RubyCAS::Server::Core::Tickets::Generations
          extend ::RubyCAS::Server::Core::Tickets::Validations
          def self.validate(pgt)
            validate_proxy_granting_ticket(pgt)
          end

          def self.create(pgt_url, pt, client = 'localhost')
            generate_proxy_granting_ticket(pgt_url, pt, client)
          end
        end

        class PT
          extend ::RubyCAS::Server::Core::Tickets::Generations
          extend ::RubyCAS::Server::Core::Tickets::Validations
          def self.validate(service, ticket)
            validate_proxy_ticket(service, ticket)
          end

          def self.create(target_service, pgt, client = 'localhost')
            generate_proxy_ticket(target_service, pgt, client)
          end
        end

        class ST
          extend ::RubyCAS::Server::Core::Tickets::Generations
          extend ::RubyCAS::Server::Core::Tickets::Validations
          def self.send_logout_notifications(st)
            send_logout_notification_for_service_ticket(st)
          end
        end
      end
    end
  end
end
