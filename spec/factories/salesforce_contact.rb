FactoryBot.define do

  # Represents a Contact returned from the Salesforce API

  factory :salesforce_contact, class: Hash do
    transient do
      sequence(:discord_user_id) { |i| "#{i}" }
    end

    skip_create # This isn't stored in the DB.
    sequence(:Id) { |i| "003a%011dAAQ" % i }
    sequence(:FirstName) { |i| "FirstName#{i}" }
    sequence(:LastName) { |i| "LastName#{i}" }
    sequence(:Preferred_First_Name__c) { |i| "PrefFirstName#{i}" }
    sequence(:Email) { |i| "testcontact#{i}@email.com" }
    sequence(:Discord_User_ID__c) { discord_user_id }

    factory :salesforce_contact_in_portal, class: Hash do
      sequence(:Canvas_Cloud_User_ID__c)
    end

    initialize_with { attributes.stringify_keys }
  end

end

# Example
#{
#    "Anticipated_Graduation__c": null,
#    "BZ_Geographical_Region__c": null,
#    "BZ_Region__c": "San Francisco Bay Area, San Jose",
#    "Career__c": null,
#    "CreatedDate": "2020-04-20T17:04:21.000+0000",
#    "Current_Employer__c": null,
#    "Current_Major__c": null,
#    "Email": "brian+xtestsyncfellowsjsu3@bebraven.org",
#    "FirstName": "Brian",
#    "Graduate_Year__c": null,
#    "High_School_Graduation_Date__c": null,
#    "Id": "003170000125IpSAAU",
#    "IsEmailBounced": false,
#    "Job_Function__c": null,
#    "LastName": "xTestSyncFellowSJSU3",
#    "Phone": null,
#    "Preferred_First_Name__c": "Brian",
#    "Signup_Date__c": null,
#    "Title": null,
#    "attributes": {
#        "type": "Contact",
#        "url": "/services/data/v48.0/sobjects/Contact/003170000125IpSAAU"
#    }
#}

