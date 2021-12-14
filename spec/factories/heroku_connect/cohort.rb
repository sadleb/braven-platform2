FactoryBot.define do
  factory :heroku_connect_cohort, class: 'heroku_connect/cohort' do
    sequence(:id)
    sequence(:sfid) { |i| "003a%011dZAZ" % i }
    createddate { Time.now.utc.strftime("%F %T") }
    isdeleted { false }
    sequence(:name) {|i| "C#{i} Tues (Heroku Connect)" }
    sequence(:dlrs_lc1_first_name__c) {|i| "TestLC1First_#{i}"}
    sequence(:dlrs_lc1_last_name__c) {|i| "TestLC1Last_#{i}"}
    dlrs_lc_total__c { 1 }

    association :program, factory: :heroku_connect_program
    association :cohort_schedule, factory: :heroku_connect_cohort_schedule

    factory :heroku_connect_cohort_co_lcs, class: 'heroku_connect/cohort' do
      # The naming is confusing, but this is actually the seconday LC. The primary
      # is stored in the 1 field
      sequence(:dlrs_lc_firstname__c) {|i| "TestLC2First_#{i}"}
      sequence(:dlrs_lc_lastname__c) {|i| "TestLC2Last_#{i}"}
      dlrs_lc_total__c { 2 }
    end
  end
end
