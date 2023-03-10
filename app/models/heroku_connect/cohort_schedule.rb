# frozen_string_literal: true

class HerokuConnect::CohortSchedule < HerokuConnect::HerokuConnectRecord
  self.table_name = 'cohortschedule__c'

  has_many :cohorts, foreign_key: 'cohort_schedule__c'
  has_many :participants, foreign_key: 'cohort_schedule__c'
  belongs_to :program, foreign_key: 'program__c'

  # Note: webinar_registration_1__c & webinar_registration_2__c
  # are the Zoom Meeting IDs.

  # IMPORTANT: Add columns you want to select by default here. If a new
  # Salesforce field is mapped in Heroku Connect that you want to use,
  # it must be added to this list.
  #
  # See HerokuConnect::HerokuConnectRecord for more info
  def self.default_columns
    [
      :id, :sfid, :createddate, :isdeleted,
      :name,
      :time__c,
      :weekday__c,
      :webinar_registration_1__c, # aka: zoom_meeting_id_1
      :webinar_registration_2__c, # aka: zoom_meeting_id_2
      :program__c,
    ]
  end

  # Implements the same logic as the DayTime__c field in Salesforce. Heroku Connect
  # can't sync formula fields so we're reimplementing the logic here.
  def canvas_section_name
    HerokuConnect::CohortSchedule.calculate_canvas_section_name(sfid, weekday__c, time__c)
  end

  def self.calculate_canvas_section_name(salesforce_id, weekday, time)
    unless weekday.present?
      raise ArgumentError, "Cohort Schedule ID: '#{salesforce_id}' does not have a Weekday set. Set that and try again."
    end
    ret = weekday
    ret = "#{ret}, #{time}" unless time.blank?
    ret
  end
end
