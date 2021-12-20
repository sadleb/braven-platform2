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
    HerokuConnect::Cohort.calculate_zoom_prefix(
      dlrs_lc_total__c,
      dlrs_lc1_first_name__c,
      dlrs_lc1_last_name__c,
      dlrs_lc_firstname__c, # For legacy reasons, the secondary LC is stored with no number in the field name
      dlrs_lc_lastname__c
    )
  end

  def self.calculate_zoom_prefix(lc_count, lc1_first_name, lc1_last_name, lc2_first_name=nil, lc2_last_name=nil)
    ret = lc1_first_name.dup
    ret << " #{lc1_last_name[0].upcase}." if lc1_last_name.present?
    if lc_count.to_i > 1 && lc2_first_name.present?
      # Co-LCs
      ret << " / #{lc2_first_name}"
      ret <<  " #{lc2_last_name[0].upcase}." if lc2_last_name.present?
    end
    ret
  end
end
