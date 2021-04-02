# frozen_string_literal: true

# This is a part of Braven Network.
# Please don't add features to Braven Network.
# This code should be considered unsupported. We want to remove it ASAP.
class ChampionContactPolicy < ApplicationPolicy
  def show?
    # Only if you created it.
    record.user == user
  end

  def delete?
    show? && record.can_fellow_cancel?
  end

  def fellow_survey?
    show?
  end

  def fellow_survey_save?
    show?
  end

  def champion_survey?
    # NOTE: Permissions handled in controller.
    # Anonymous access with nonce param.
    true
  end

  def champion_survey_save?
    # NOTE: Permissions handled in controller.
    # Anonymous access with nonce param.
    true
  end
end
