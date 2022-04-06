# frozen_string_literal: true

class HerokuConnect::Program < HerokuConnect::HerokuConnectRecord
  self.table_name = 'program__c'

  # type cast these from strings to symbols to make the code cleaner
  attribute :status__c, :symbol

  has_many :candidates, foreign_key: 'program__c'
  has_many :participants, foreign_key: 'program__c'
  # Careful with these, TA enrollments may include TAs, Staff, and guests.
  has_many :ta_participants, -> {
      joins(:record_type).where('recordtype.name = ?', SalesforceConstants::RoleCategory::TEACHING_ASSISTANT)
    }, foreign_key: 'program__c', class_name: HerokuConnect::Participant.name
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
      :default_timezone__c,
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
    .compact
  }

  # The local Platform Course model for the Accelerator course.
  #
  # Note that this can't be an association (aka join) b/c in dev the HerokuConnect
  # and Platform databases aren't the same and you can't join across different databases.
  def accelerator_course
    Course.find_by_canvas_course_id(canvas_cloud_accelerator_course_id__c)
  end

  # The local Platform Course model for the LC Playbook course.
  #
  # Note that this can't be an association (aka join) b/c in dev the HerokuConnect
  # and Platform databases aren't the same and you can't join across different databases.
  def lc_playbook_course
    Course.find_by_canvas_course_id(canvas_cloud_lc_playbook_course_id__c)
  end

  # Both the Accelerator and LC Playbook courses for this Program
  def courses
    Course.where(canvas_course_id: [
      canvas_cloud_accelerator_course_id__c,
      canvas_cloud_lc_playbook_course_id__c
    ].compact) # compact is so that if one isn't set, we don't end up getting courses with a nil canvas_course_id
  end

  # The time_zone associated with this Program in IANA format. Used to create
  # the Canvas courses when the Progam is launched. See: CanvasAPI#create_course
  def time_zone
    default_timezone__c
  end

  # The unique ID for this Program used when doing SIS Imports.
  # For more infor, see the SisImportDataSet class and
  # https://github.com/bebraven/platform/wiki/Salesforce-Sync#datasets-and-diffing
  def sis_import_data_set_id
    "SisImport_SFProgram_#{sfid}"
  end

  # The name of the Canvas "term" for this Program.
  # Both the Accelerator and LC Playbook courses for a Program are in the same term.
  #
  # Having one of these allows us to fix up the users, sections, enrollments, etc using
  # an SIS Import in Batch Mode if something gets messed up with the sync.
  # See Batch Mode section here:
  # https://canvas.instructure.com/doc/api/file.sis_csv.html
  #
  # Task to create UI tool to force an import in "fix it up" mode:
  # https://app.asana.com/0/1201131148207877/1201868573784350
  def term_name
    name
  end

  # A globally unique ID for Canvas "term". See term_name above for more info.
  def sis_term_id
    "Term_SFProgramId_#{sfid}"
  end

  # Adds common Honeycomb fields to every span in the trace. Useful to be able to group
  # any particular field you're querying for by the program.
  #
  # IMPORTANT: if you need information on multiple Programs in a trace, DO NOT USE THIS.
  # Whatever the values for the last Program are will overwrite all the other Program info.
  def add_to_honeycomb_trace
    Honeycomb.add_field_to_trace("salesforce.program.id", sfid)
    attributes.each_pair { |attr, value|
      # These are HerokuConnect attributes that are meaningless (and confusing if named salesforce.program.id)
      next if attr == 'id' || attr == 'isdeleted'

      Honeycomb.add_field_to_trace("salesforce.program.#{attr}", value.to_s)
    }
  end

end
