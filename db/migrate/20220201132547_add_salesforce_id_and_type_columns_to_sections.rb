class AddSalesforceIdAndTypeColumnsToSections < ActiveRecord::Migration[6.1]
  def up
    # If set, the salesforce_id will either be the Cohort__c.Id, CohortSchedule__c.Id
    # or the Participant.Id of the TA (for TA Caseloads) depending on the `section_type` column.
    add_column :sections, :salesforce_id, :string, limit: 18
    add_index :sections, :course_id
    add_index :sections, :salesforce_id
    add_index :sections, [:salesforce_id, :course_id], :unique => true
    add_check_constraint(:sections,
      "char_length(salesforce_id) IN (18, NULL)",
      name: 'chk_sections_salesforce_id_length'
    )

    add_column :sections, :section_type, :string, limit: 20
    contraint_sql = <<~SQL
    section_type IN (
      '#{Section::Type::COHORT}',
      '#{Section::Type::COHORT_SCHEDULE}',
      '#{Section::Type::TEACHING_ASSISTANTS}',
      '#{Section::Type::TA_CASELOAD}',
      '#{Section::Type::DEFAULT_SECTION}'
    )
    SQL
    add_check_constraint :sections, contraint_sql, name: 'chk_sections_type'

    # Note: there will be old Sections left behind without the type/salesforce_id set.
    # Those should all be test sections, not real Salesforce ones and it just means we
    # can't update / sync them anymore.
    populate_existing_cohort_schedule_sections
    populate_existing_cohort_sections
    populate_existing_teaching_assistant_sections
    populate_existing_default_sections
    # Note: there are no TA Caseload Sections locally before this. They are in Canvas only.
    # See the sis_import.rake task for where we migrate them.
  end

  def down
    remove_check_constraint(:sections, name: 'chk_sections_salesforce_id_length')
    remove_check_constraint(:sections, name: 'chk_sections_type')
    remove_index(:sections, name: 'index_sections_on_course_id')
    remove_column :sections, :section_type
    remove_column :sections, :salesforce_id
  end

  def populate_existing_cohort_schedule_sections
    changed_sections = []
    cohort_schedules = HerokuConnect::CohortSchedule.joins(:program).unscope(:select)
      .select(:weekday__c, :time__c, :sfid, :'program__c.canvas_cloud_accelerator_course_id__c')
    cohort_schedules.each { |cs|
      course = Course.find_by_canvas_course_id(cs.canvas_cloud_accelerator_course_id__c)
      next unless course # let this run in both dev and prod by skipping missing local courses
      course.sections.each { |s|
        # Note: these names originally came from the CohortSchedule.DayTime__c formula field in Salesforce.
        if s.canvas_section_id.present? && s.name == cs.canvas_section_name
          s.salesforce_id = cs.sfid
          s.section_type = Section::Type::COHORT_SCHEDULE
          s.save!
          changed_sections << s
        end
      }
    }
    puts "\n### Updated the following Cohort Schedule Sections with a salesforce_id and section_type: "
    changed_sections.each { |changed| puts changed.inspect }
  end

  def populate_existing_cohort_sections
    changed_sections = []
    cohorts = HerokuConnect::Cohort.joins(:program).unscope(:select)
      .select(:name, :sfid, :'program__c.canvas_cloud_accelerator_course_id__c')
    cohorts.each { |c|
      course = Course.find_by_canvas_course_id(c.canvas_cloud_accelerator_course_id__c)
      next unless course # let this run in both dev and prod by skipping missing local courses
      course.sections.each { |s|
        if s.canvas_section_id.present? && s.name == c.name
          s.salesforce_id = c.sfid
          s.section_type = Section::Type::COHORT
          s.save!
          changed_sections << s
        end
      }
    }
    puts "\n### Updated the following Cohort Sections with a salesforce_id and section_type: "
    changed_sections.each { |changed| puts changed.inspect }
  end

  def populate_existing_teaching_assistant_sections
    changed_sections = []
    Section.where(name: SectionConstants::TA_SECTION).where.not(canvas_section_id: nil).each { |s|
      s.update!(section_type: Section::Type::TEACHING_ASSISTANTS); changed_sections << s
    }
    puts "\n### Updated the following Teaching Assistant Sections with a section_type: "
    changed_sections.each { |changed| puts changed.inspect }
  end

  def populate_existing_default_sections
    changed_sections = []
    Section.where(name: SectionConstants::DEFAULT_SECTION).where.not(canvas_section_id: nil).each { |s|
      s.update!(section_type: Section::Type::DEFAULT_SECTION); changed_sections << s
    }
    puts "\n### Updated the following Default Sections with a section_type: "
    changed_sections.each { |changed| puts changed.inspect }
  end
end
