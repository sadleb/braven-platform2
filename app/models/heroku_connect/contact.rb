# frozen_string_literal: true

class HerokuConnect::Contact < HerokuConnect::HerokuConnectRecord
  self.table_name = 'contact'

  has_many :participants, foreign_key: 'contact__c'
  has_many :candidates, foreign_key: 'contact__c'


  # IMPORTANT: Add columns you want to select by default here. If a new
  # Salesforce field is mapped in Heroku Connect that you want to use,
  # it must be added to this list.
  #
  # See HerokuConnect::HerokuConnectRecord for more info
  def self.default_columns
    [
      :id, :sfid, :createddate, :isdeleted,
      :name, :firstname, :lastname, :email, :preferred_first_name__c,
      :canvas_cloud_user_id__c,
      :discord_user_id__c,
      :platform_user_id__c,
      :signup_date__c,
    ]
  end

  def first_name
    firstname
  end

  def last_name
    lastname
  end

  def canvas_user_id
    canvas_cloud_user_id__c
  end

  def user_id
    platform_user_id__c
  end
end
