FactoryBot.define do
  factory :section do
    sequence(:name) { |i| "Section Name #{i}" }
    section_type { Section::Type::DEFAULT_SECTION }
    sequence(:canvas_section_id)
    association :course

    factory :cohort_schedule_section do
      transient do
        # If you need a local Section to match a HerokuConnect::CohortSchedule
        # pass that in when creating one of these factories
        cohort_schedule { build :heroku_connect_cohort_schedule }
      end

      name { cohort_schedule.canvas_section_name }
      section_type { Section::Type::COHORT_SCHEDULE }
      salesforce_id { cohort_schedule.sfid }
    end

    factory :cohort_section do
      transient do
        # If you need a local Section to match a HerokuConnect::Cohort
        # pass that in when creating one of these factories
        cohort { build :heroku_connect_cohort }
      end

      name { cohort.name }
      section_type { Section::Type::COHORT }
      salesforce_id { cohort.sfid }
    end

    factory :ta_section do
      name { SectionConstants::TA_SECTION }
      section_type { Section::Type::TEACHING_ASSISTANTS }
      sequence(:salesforce_id) {|i| "003x%011dSSA" % i }
    end

    factory :ta_caseload_section do
      sequence(:name) { |i| "TA Caseload(#{i}" }
      section_type { Section::Type::TA_CASELOAD}
      sequence(:salesforce_id) {|i| "003x%011dSSB" % i }
    end

  end
end
