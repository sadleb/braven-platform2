FactoryBot.define do
  factory :heroku_connect_contact, class: 'heroku_connect/contact' do
    sequence(:id)
    sequence(:platform_user_id__c)

    # Note: salesforce IDs need to be 18 chars and unique. It's important to use a slight
    # variation of the pattern for different factories to avoid collisions. We allow want to allow as
    # big of an integer as possible so it doesn't overflow. Right now we can go up to 11 character digits,
    # so this won't start failing until we create 100 billion users as part of running our specs.
    sequence(:sfid) { |i| "003a%011dYYZ" % i }

    createddate { Time.now.utc.strftime("%F %T") }
    isdeleted { false }
    sequence(:firstname) { |i| "TestContactFirst#{i}" }
    sequence(:lastname) { |i| "TestContactLast#{i}" }
    name { "#{firstname} #{lastname}" }
    sequence(:email) {|i| "contact_email#{i}@example.com"}
    preferred_first_name__c { "#{firstname}_preferred" }
    sequence(:canvas_cloud_user_id__c)
    sequence(:discord_user_id__c)
  end
end
