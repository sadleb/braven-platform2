FactoryBot.define do
  factory :heroku_connect_program, class: 'heroku_connect/program' do
    sequence(:id)
    sequence(:sfid) { |i| "003a%011dZXX" % i }
    createddate { Time.now.utc.strftime("%F %T") }
    isdeleted { false }
    sequence(:name) {|i| "Heroku Connect Proram#{i}" }
    status__c { HerokuConnect::Program::Status::CURRENT }
    recordtypeid { record_type.sfid }
    sequence(:canvas_cloud_accelerator_course_id__c)
    sequence(:canvas_cloud_lc_playbook_course_id__c)
    sequence(:discord_server_id__c)
    # This is the format that Salesforce sends.
    program_start_date__c { Time.now.utc.strftime("%F") }
    program_end_date__c { Time.now.utc.strftime("%F") }

    association :record_type, factory: :heroku_connect_record_type

    factory :heroku_connect_program_unlaunched, class: 'heroku_connect/program' do
      canvas_cloud_accelerator_course_id__c { nil }
      canvas_cloud_lc_playbook_course_id__c { nil }
      cohort_schedules { build_list(:heroku_connect_cohort_schedule, 2) }
    end

    factory :heroku_connect_program_launched, class: 'heroku_connect/program' do
      transient do
        accelerator_course { create :course_launched, salesforce_program_id: sfid }
        lc_playbook_course { create :course_launched, salesforce_program_id: sfid }
      end

      canvas_cloud_accelerator_course_id__c { accelerator_course.canvas_course_id }
      canvas_cloud_lc_playbook_course_id__c { lc_playbook_course.canvas_course_id }
      cohort_schedules { build_list(:heroku_connect_cohort_schedule, 2) }
    end
  end
end
