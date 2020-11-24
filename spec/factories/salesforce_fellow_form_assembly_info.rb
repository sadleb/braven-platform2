FactoryBot.define do

  # Represents the info returned from SaleforceAPI.get_fellow_form_assembly_info(...)

  factory :salesforce_fellow_form_assembly_info, class: Hash do
    skip_create # This isn't stored in the DB.
    done { true }
    records { [ build(:salesforce_fellow_form_assembly_info_record) ] }
    totalSize { records.count }
    initialize_with { attributes.stringify_keys }
  end

  factory :salesforce_fellow_form_assembly_info_record, class: Hash do
    skip_create # This isn't stored in the DB.

    transient do
      sequence(:program_id) { |i| "a2Y#{i}1000001HY5mEAG" }
    end

    sequence(:Id) { program_id }
    sequence(:attributes) { |i| 
      "{'type':'Program__c', 'url':'/services/data/v49.0/sobjects/Program__c/#{program_id}'}'"
    }
    sequence(:FA_ID_Fellow_Waivers__c) { |i| 7777 + i }
    sequence(:FA_ID_Fellow_PreSurvey__c) { |i| 8888 + i }
    sequence(:FA_ID_Fellow_PostSurvey__c) { |i| 9999 + i }

    initialize_with { attributes.stringify_keys }
  end

end

# Example
# {
#   "attributes":
#   {
#     "type":"Program__c", 
#     "url":"/services/data/v49.0/sobjects/Program__c/a2Y11000001HY5mEAG"
#   }, 
#   "FA_ID_Fellow_Waivers__c":"4810809",
#   "FA_ID_Fellow_PreSurvey__c":"4810810",
#   "FA_ID_Fellow_PostSurvey__c":"4810811",
# }
