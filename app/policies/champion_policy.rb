# frozen_string_literal: true

# This is a part of Braven Network.
# Please don't add features to Braven Network.
# This code should be considered unsupported. We want to remove it ASAP.
class ChampionPolicy < ApplicationPolicy
  def new?
    # Allow anonymous access.
    true
  end

  def create?
    new?
  end

  def connect?
    # Any logged-in user.
    !!user
  end

  def request_contact?
    connect?
  end

  def contact?
    connect?
  end

  def terms?
    connect?
  end

end
