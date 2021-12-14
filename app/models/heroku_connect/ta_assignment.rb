# frozen_string_literal: true

class HerokuConnect::TaAssignment < HerokuConnect::HerokuConnectRecord
  self.table_name = 'ta_assignment__c'

  belongs_to :fellow_participant, foreign_key: 'fellow_participant__c', class_name: 'HerokuConnect::Participant'
  belongs_to :ta_participant, foreign_key: 'ta_participant__c', class_name: 'HerokuConnect::Participant'
  belongs_to :program, foreign_key: 'program__c'

  # IMPORTANT: Add columns you want to select by default here. If a new
  # Salesforce field is mapped in Heroku Connect that you want to use,
  # it must be added to this list.
  #
  # See HerokuConnect::HerokuConnectRecord for more info
  def self.default_columns
    [
      :id, :sfid, :createddate, :isdeleted,
      :name,
      :fellow_participant__c,
      :ta_participant__c,
      :program__c,
    ]
  end
end
