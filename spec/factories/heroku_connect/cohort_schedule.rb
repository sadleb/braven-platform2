FactoryBot.define do
  factory :heroku_connect_cohort_schedule, class: 'heroku_connect/cohort_schedule' do
    sequence(:id)
    sequence(:sfid) { |i| "003a%011dYAZ" % i }
    createddate { Time.now.utc.strftime("%F %T") }
    isdeleted { false }
    sequence(:name) {|i| "Thursday: Some Program Name" }
    time__c { '6:00 - 8:00 p.m. Eastern' }
    weekday__c { 'Thursday' }
    sequence(:webinar_registration_1__c) # aka: zoom_meeting_id_1
    sequence(:webinar_registration_2__c) # aka: zoom_meeting_id_2

    association :program, factory: :heroku_connect_program

  end
end
