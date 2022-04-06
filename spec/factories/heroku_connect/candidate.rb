FactoryBot.define do
  factory :heroku_connect_candidate, class: 'heroku_connect/candidate' do
    sequence(:id)
    sequence(:sfid) { |i| "003a%011dZYQ" % i }
    createddate { Time.now.utc.strftime("%F %T") }
    isdeleted { false }
    sequence(:name) {|i| "Heroku Connect Candate#{i}" }
    status__c { HerokuConnect::Candidate::Status::FULLY_CONFIRMED }
    recordtypeid { record_type.sfid }
    coach_partner_role__c { nil }

    association :record_type, factory: :heroku_connect_record_type
    association :contact, factory: :heroku_connect_contact
    association :program, factory: :heroku_connect_program

    factory :heroku_connect_fellow_candidate, class: 'heroku_connect/candidate' do
      association :record_type, factory: :heroku_connect_record_type, name: SalesforceConstants::RoleCategory::FELLOW
    end

    factory :heroku_connect_lc_candidate, class: 'heroku_connect/candidate' do
      association :record_type, factory: :heroku_connect_record_type, name: SalesforceConstants::RoleCategory::LEADERSHIP_COACH

      factory :heroku_connect_cp_candidate, class: 'heroku_connect/candidate' do
        coach_partner_role__c { SalesforceConstants::Role::COACH_PARTNER }
      end
    end

    factory :heroku_connect_ta_candidate, class: 'heroku_connect/candidate' do
      association :record_type, factory: :heroku_connect_record_type, name: SalesforceConstants::RoleCategory::TEACHING_ASSISTANT

      factory :heroku_connect_staff_candidate, class: 'heroku_connect/candidate' do
        coach_partner_role__c { SalesforceConstants::Role::STAFF }
      end

      factory :heroku_connect_faculty_candidate, class: 'heroku_connect/candidate' do
        coach_partner_role__c { SalesforceConstants::Role::FACULTY }
      end
    end
  end
end
