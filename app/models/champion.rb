# frozen_string_literal: true

# This is a part of Braven Network.
# Please don't add features to Braven Network.
# This code should be considered unsupported. We want to remove it ASAP.
require 'salesforce_api'

class Champion < ApplicationRecord
  # https://api.rubyonrails.org/classes/ActiveRecord/Base.html#class-ActiveRecord::Base-label-Saving+arrays-2C+hashes-2C+and+other+non-mappable+objects+in+text+columns
  serialize :industries, Array
  serialize :studies, Array

  has_many :champion_contacts

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true
  validates :industries, presence: true
  validates :studies, presence: true
  validates :linkedin_url, presence: true

  def full_name
    [first_name, last_name].join(' ')
  end

  def interests
    [studies, industries].flatten.sort.uniq
  end

  def too_recently_contacted
    flood_check = ChampionContact.where(:champion_id => self.id).where("created_at > ?", 2.weeks.ago.end_of_day)
    return true if flood_check.any?

    semester_check = ChampionContact.where(:champion_id => self.id).where("created_at > ?", 3.months.ago)
    return true if semester_check.count >= 3

    false
  end

  # Direct port of the old create_on_salesforce method in the Join server code,
  # but using the Salesforce REST API instead of the databasedotcom gem
  def create_or_update_on_salesforce

    contact = {}
    contact['OwnerId'] = ENV['CHAMPION_SALESFORCE_CAMPAIGN_OWNER_ID']
    contact['FirstName'] = first_name.split.map(&:capitalize).join(' ')
    contact['LastName'] = last_name.split.map(&:capitalize).join(' ')
    # Email is in the URL, not the body
    # contact['Email'] = email
    contact['Phone'] = phone
    contact['Company__c'] = company
    contact['Title'] = job_title
    contact['LinkedIn_URL__c'] = linkedin_url
    contact['Industry_Experience__c'] = industries.join(', ')
    contact['Fields_Of_Study__c'] = studies.join(', ')
    # BZ_Region is required, so if they don't choose a region default them to National
    contact['BZ_Region__c'] = region.blank? ? 'National' : region
    contact['Signup_Date__c'] = created_at
    contact['User_Type__c'] = 'Champion'
    contact['Champion_Information__c'] = 'Current'

    response = SalesforceAPI.client.create_or_update_contact(email, contact)
    self.salesforce_id = response['id']

    # We can't do an upsert on a CampaignMember like we do for the contact b/c it's a join table
    # between Contact and Campaign so there is no unique field on it other than the ID. If there is
    # is already a CampaignMember we still want to update it in case they opt-out at some point and
    # we mark them as not "Confirmed" so they stop getting emails, but then the sign-up again to opt back in.
    if self.salesforce_campaign_member_id.present?
      cm = { 'Candidate_Status__c' => 'Confirmed' }
      SalesforceAPI.client.update_campaign_member(self.salesforce_campaign_member_id, cm)
    else
      cm = {}
      cm['CampaignId'] = ENV['CHAMPION_SALESFORCE_CAMPAIGN_ID'] 
      cm['ContactId'] = self.salesforce_id
      cm['Candidate_Status__c'] = 'Confirmed'
      response = SalesforceAPI.client.create_campaign_member(cm)
      self.salesforce_campaign_member_id = response['id']
    end

    save!
  end

end
