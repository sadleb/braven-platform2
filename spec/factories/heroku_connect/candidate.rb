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

  end
end
