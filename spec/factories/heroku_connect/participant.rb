FactoryBot.define do
  factory :heroku_connect_participant, class: 'heroku_connect/participant' do
    sequence(:id)
    sequence(:sfid) { |i| "003a%011dZZQ" % i }
    createddate { Time.now.utc.strftime("%F %T") }
    isdeleted { false }
    sequence(:name) {|i| "Heroku Connect Participant#{i}" }
    status__c { HerokuConnect::Participant::Status::ENROLLED }
    recordtypeid { record_type.sfid }
    sequence(:webinar_access_1__c) { |i| "https://fake.zoom.link/zoom_meeting_1/#{i}"}
    sequence(:webinar_access_2__c) { |i| "https://fake.zoom.link/zoom_meeting_2/#{i}"}

    association :record_type, factory: :heroku_connect_record_type
    association :contact, factory: :heroku_connect_contact
    association :candidate, factory: :heroku_connect_candidate
    association :program, factory: :heroku_connect_program
    association :cohort, factory: :heroku_connect_cohort
    association :cohort_schedule, factory: :heroku_connect_cohort_schedule

    factory :heroku_connect_fellow_participant, class: 'heroku_connect/participant' do
      association :record_type, factory: :heroku_connect_record_type, name: SalesforceConstants::RoleCategory::FELLOW
      association :candidate, factory: :heroku_connect_fellow_candidate
    end

    factory :heroku_connect_lc_participant, class: 'heroku_connect/participant' do
      association :record_type, factory: :heroku_connect_record_type, name: SalesforceConstants::RoleCategory::LEADERSHIP_COACH
      association :candidate, factory: :heroku_connect_lc_candidate

      factory :heroku_connect_cp_participant, class: 'heroku_connect/participant' do
        association :candidate, factory: :heroku_connect_cp_candidate
      end
    end

    factory :heroku_connect_ta_participant, class: 'heroku_connect/participant' do
      association :record_type, factory: :heroku_connect_record_type, name: SalesforceConstants::RoleCategory::TEACHING_ASSISTANT
      association :candidate, factory: :heroku_connect_ta_candidate

      factory :heroku_connect_staff_participant, class: 'heroku_connect/participant' do
        association :candidate, factory: :heroku_connect_staff_candidate
      end

      factory :heroku_connect_faculty_participant, class: 'heroku_connect/participant' do
        association :candidate, factory: :heroku_connect_faculty_candidate
      end
    end
  end
end
