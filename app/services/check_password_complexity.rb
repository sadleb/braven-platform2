# frozen_string_literal: true

# Checks for VERY basic password complexity. We're just trying to prevent
# folks from using a password like "password" but we don't want to make it hard
# to pick a password that works. We have an alert for brute force attempts so any password
# that would require a brute force approach (as opposed to just trying a handful of really
# common passwords) should be fine to allow.
#
# Assumes that the password being checked is at least 8 characters long which is the
# enforced using Devise's config.password_length.
#
# Note that I started trying to use the strong_password gem for this, but the algorithm
# heavily discounts repeated characters and doesn't give credit for mixed case when
# calculating strength so a lot of my 8 char passwords would fail. Eventually, we should
# use a 3rd party like auth0 for authentication.
class CheckPasswordComplexity

  def initialize(password)
    @password = password
  end

  # Returns true if the password is complex enough and false if not. "complex" here just
  # means it's not one of the most common passwords greator than or equal to 8 characters.
  def run
    !password_dictionary.include?(@password.downcase)
  end

private

  def password_dictionary
    @@password_dictionary ||=  begin
      File.read(Rails.public_path.join('common-over-8char-passwords.txt')).split.to_set
    end
  end

end
