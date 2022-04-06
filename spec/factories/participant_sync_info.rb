FactoryBot.define do
  factory :participant_sync_info do

    transient do
      # If you need a ParticipantSyncInfo to match a HerokuConnect::Participant,
      # pass that in when creating one of these factories
      participant { build :heroku_connect_participant }
      contact { participant.contact }
      program { participant.program }
      cohort_schedule { participant.cohort_schedule }
      cohort { participant.cohort }
    end

    sfid { participant.sfid }
    first_name { contact.first_name }
    last_name { contact.last_name }
    email { contact.email }
    contact_id { contact.sfid }
    user_id { contact.user_id }
    canvas_user_id { contact.canvas_user_id }
    status { participant.status__c }
    role_category { participant.record_type.name }
    program_id { program.sfid }
    canvas_accelerator_course_id { program.canvas_cloud_accelerator_course_id__c }
    canvas_lc_playbook_course_id { program.canvas_cloud_lc_playbook_course_id__c }

    # This is an association, but trying to pass a transient variable isn't working
    # when using the association :user, factory: :registered_user, contact: contact
    # syntax
    user { create :registered_user, contact: contact }

    factory :participant_sync_info_ta do
      transient do
        participant { build :heroku_connect_ta_participant }
      end

      factory :participant_sync_info_ta_with_ta_caseload do
        ta_caseload_enrollments {
          [{"ta_name"=>"#{first_name} #{last_name}", "ta_participant_id"=>sfid}]
        }
      end

      factory :participant_sync_info_staff do
        candidate_role_select { SalesforceConstants::Role::STAFF }
      end

      factory :participant_sync_info_faculty do
        candidate_role_select { SalesforceConstants::Role::FACULTY }
      end
    end

    factory :participant_sync_info_with_cohort do
      cohort_section { create :cohort_section, cohort: cohort }
      cohort_schedule_section { create :cohort_schedule_section, cohort_schedule: cohort_schedule }

      cohort_schedule_id { cohort_schedule.sfid }
      cohort_schedule_weekday { cohort_schedule.weekday__c }
      cohort_schedule_time { cohort_schedule.time__c }
      zoom_meeting_id_1 { cohort_schedule.webinar_registration_1__c }
      zoom_meeting_id_2 { cohort_schedule.webinar_registration_2__c }

      cohort_id { cohort.sfid }
      cohort_section_name { cohort.name }
      lc1_first_name { cohort.dlrs_lc1_first_name__c }
      lc1_last_name { cohort.dlrs_lc1_last_name__c }
      lc2_first_name { cohort.dlrs_lc_firstname__c }
      lc2_last_name { cohort.dlrs_lc_lastname__c }
      lc_count { cohort.dlrs_lc_total__c }

      factory :participant_sync_info_fellow do
        transient do
          participant { build :heroku_connect_fellow_participant }
        end
        user { create :fellow_user, contact: contact, section: cohort_section }

        factory :participant_sync_info_fellow_unmapped do
          # override the associations
          cohort_section { nil }
          user { create :fellow_user, contact: contact, section: cohort_schedule_section }
        end

        factory :participant_sync_info_fellow_with_ta_caseload do
          sequence(:ta_caseload_enrollments) { |i|
            [{"ta_name"=>"TAFirst xTestTALast#{i}", "ta_participant_id"=>"a2XX%011dBAE" % i}]
          }
        end
      end

      factory :participant_sync_info_lc do
        transient do
          participant { build :heroku_connect_lc_participant }
        end
        user { create :ta_user, contact: contact, section: cohort_section }
      end

      factory :participant_sync_info_cp do
        transient do
          participant { build :heroku_connect_cp_participant }
        end
        user { create :ta_user, contact: contact, section: cohort_section }
      end

    end # participant_sync_info_with_cohort
  end
end
