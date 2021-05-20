require 'bcrypt'
module BravenCAS
  class CustomAuthenticator < RubyCAS::Server::Core::Authenticator

    # If any of the validation methods return true, this is the User
    # record it returned true for.
    attr_reader :user

    def validate(credentials)
      valid_password?(credentials) && @user.confirmed? && @user.registered?
    end

    # Used to check only the username/password validity. This doesn't mean their account
    # is fully setup and should be able to log in, but it's enough to know that we can
    # show them information about the state of their account to help them continue getting
    # it setup.
    def valid_password?(credentials)
      @user ||= User.find_by_email(credentials[:username])
      return false unless @user.present?
      return false if @user.encrypted_password.blank?
      BCrypt::Password.new(@user.encrypted_password) == credentials[:password]
    end

    # Used to check if the username/password would be valid if the unconfirmed they are
    # trying to log in with were confirmed.
    def valid_password_for_unconfirmed_email?(credentials)
      @user = User.find_by_unconfirmed_email(credentials[:username])
      return false unless @user.present?
      valid_password?(credentials)
    end
  end
end
