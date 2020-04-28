module BeyondZ
  class CustomAuthenticator < RubyCAS::Server::Core::Authenticator
    def self.setup(options)
      raise RubyCAS::Server::Core::AuthenticatorError, "Authenticator configuration needs server" unless options[:server]

      @@server = options[:server]
      @@ssl = (!options[:ssl].nil?) ? options[:ssl] : true
      @@port = (!options[:port].nil?) ? options[:port] : (@@ssl ? 443 : 80)
      @@allow_self_signed = (!options[:allow_self_signed].nil?) ? options[:allow_self_signed] : false
    end

    def validate(credentials)
      http = Net::HTTP.new(@@server, @@port)
      if @@ssl
        http.use_ssl = true
        if @@allow_self_signed
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE # self-signed cert would fail
        end
      end

      request = Net::HTTP::Post.new('/users/check_credentials')
      request.set_form_data(
        'username' => credentials[:username],
        'password' => credentials[:password]
      )
      response = http.request(request)
      return (response.body == "true")
    end
  end
end
