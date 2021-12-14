FactoryBot.define do
  factory :heroku_connect_contact, class: 'heroku_connect/contact' do
    sequence(:id)
    sequence(:sfid) { |i| "003a%011dYYZ" % i }
    createddate { Time.now.utc.strftime("%F %T") }
    isdeleted { false }
    sequence(:firstname) { |i| "TestContactFirst#{i}" }
    sequence(:lastname) { |i| "TestContactLast#{i}" }
    name { "#{firstname} #{lastname}" }
    sequence(:email) {|i| "example_hc_contact_email#{i}@example.com"}
    preferred_first_name__c { "#{firstname}_preferred" }
    sequence(:canvas_cloud_user_id__c)
    sequence(:discord_user_id__c)
  end
end
