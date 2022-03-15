# frozen_string_literal: true

class HerokuConnect::Program < HerokuConnect::HerokuConnectRecord
  self.table_name = 'program__c'

  # type cast these from strings to symbols to make the code cleaner
  attribute :status__c, :symbol

  has_many :candidates, foreign_key: 'program__c'
  has_many :participants, foreign_key: 'program__c'
  has_many :cohorts, foreign_key: 'program__c'
  has_many :cohort_schedules, foreign_key: 'program__c'
  has_many :ta_assignments, foreign_key: 'program__c'
  belongs_to :record_type, foreign_key: 'recordtypeid'

  # IMPORTANT: Add columns you want to select by default here. If a new
  # Salesforce field is mapped in Heroku Connect that you want to use,
  # it must be added to this list.
  #
  # See HerokuConnect::HerokuConnectRecord for more info
  def self.default_columns
    [
      :id, :sfid, :createddate, :isdeleted,
      :name,
      :status__c,
      :recordtypeid,
      :canvas_cloud_accelerator_course_id__c,
      :canvas_cloud_lc_playbook_course_id__c,
      :discord_server_id__c,
      :program_end_date__c,
      :program_start_date__c,
    ]
  end

  # Possible values for the status__c
  class Status
    CURRENT = :Current
    FUTURE = :Future
    FORMER = :Former
  end

  scope :current_and_future_program_ids, -> {
     joins(:record_type)
    .where(status__c: [Status::CURRENT, Status::FUTURE], record_type: {name: 'Course'})
    .pluck(:sfid)
  }

  scope :current_and_future_accelerator_canvas_course_ids, -> {
     joins(:record_type)
    .where(status__c: [Status::CURRENT, Status::FUTURE], record_type: {name: 'Course'})
    .pluck(:canvas_cloud_accelerator_course_id__c)
  }
end
