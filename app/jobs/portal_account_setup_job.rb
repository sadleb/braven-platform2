# frozen_string_literal: true

class PortalAccountSetupJob < ActiveJob::Base
  queue_as :default

  def perform(salesforce_contact_id)
    PortalAccountSetup.new(salesforce_contact_id: salesforce_contact_id).run
  end
end
