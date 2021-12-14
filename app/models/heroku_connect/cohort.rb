# frozen_string_literal: true

class HerokuConnect::Cohort < HerokuConnect::HerokuConnectRecord
  self.table_name = 'cohort__c'

  has_many :participants, foreign_key: 'cohort__c'
  belongs_to :cohort_schedule, foreign_key: 'cohort_schedule__c'
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
      :dlrs_lc_firstname__c,
      :dlrs_lc_lastname__c,
      :dlrs_lc1_first_name__c,
      :dlrs_lc1_last_name__c,
      :dlrs_lc_total__c,
      :program__c,
      :cohort_schedule__c,
    ]
  end

  # Implements the same logic as the Zoom_Prefix__c field in Salesforce. Heroku Connect
  # can't sync formula fields so we're reimplementing the logic here.
  # E.g.
  # Only one LC named "FirstName1 LastName1" => FirstName L.
  # Co-LCs names "FirstName1 LastName2" and "FirstName2 LastName2" => FirstName1 L. / FirstName2 L.
  def zoom_prefix
    ret = dlrs_lc1_first_name__c
    ret << " #{dlrs_lc1_last_name__c[0].upcase}." if dlrs_lc1_last_name__c.present?
    if dlrs_lc_total__c.to_i > 1 && dlrs_lc_firstname__c.present?
      # Co-LCs
      ret << " / #{dlrs_lc_firstname__c}"
      ret <<  " #{dlrs_lc_lastname__c[0].upcase}." if dlrs_lc_lastname__c.present?
    end
    ret
  end
end
