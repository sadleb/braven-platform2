# frozen_string_literal: true

require 'discordrb'

module Discordrb::API

  module_function

  # From https://github.com/shardlab/discordrb/blob/main/lib/discordrb/api.rb
  def raw_request(type, attributes)
    # Start of custom proxy modifications.
    proxy = ENV['FIXIE_URL']

    # See https://github.com/rest-client/rest-client/blob/2c72a2e77e2e87d25ff38feba0cf048d51bd5eca/lib/restclient.rb
    if [:post, :patch, :put].include? type
      # attributes has a payload.
      RestClient::Request.execute(
        method: type,
        url: attributes[0],
        payload: attributes[1],
        headers: attributes[2],
        proxy: proxy
        # Skip passing &block bc we don't have anything that uses it.
      )
    else
      # attributes does not have a payload.
      RestClient::Request.execute(
        method: type,
        url: attributes[0],
        headers: attributes[1],
        proxy: proxy
        # Skip passing &block bc we don't have anything that uses it.
      )
    end
    # /End custom proxy modifications.

  # Keep everything else in this function in sync with the upstream method!
  rescue RestClient::Forbidden => e
    # HACK: for #request, dynamically inject restclient's response into NoPermission - this allows us to rate limit
    noprm = Discordrb::Errors::NoPermission.new
    noprm.define_singleton_method(:_rc_response) { e.response }
    raise noprm, 'The bot doesn\'t have the required permission to do this!'
  rescue RestClient::BadGateway
    Discordrb::LOGGER.warn('Got a 502 while sending a request! Not a big deal, retrying the request')
    retry
  end
end
