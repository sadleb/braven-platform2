FactoryBot.define do

  # Represents a Program returned from the Salesforce API

  factory :salesforce_program, class: Hash do
    skip_create # This isn't stored in the DB.
    done { true }
    records { [ build(:salesforce_program_record) ] }
    totalSize { records.count }
    initialize_with { attributes.stringify_keys }
  end

  factory :salesforce_program_record, class: Hash do
    skip_create # This isn't stored in the DB.
    Default_Timezone__c { 'America/Los_Angeles' }
    sequence(:Docusign_Template_ID__c) { |i| "TestDocusignTemplate#{i}" }
    sequence(:Id) { |i| "a2Y1700000#{i}WLxqEAG" }
    sequence(:Highlander_LCPlaybook_Course_ID__c)
    sequence(:Name) { |i| "TEST: Program#{i}" }
    sequence(:Preaccelerator_Qualtrics_Survey_ID__c) { |i| "TestQualtricsSurvey#{i}" }
    sequence(:Postaccelerator_Qualtrics_Survey_ID__c) { |i| "TestQualtricsSurvey#{i}" }
    sequence(:School__c) { |i| "0011700001#{i}xF2cAAE" }
    sequence(:Section_Name_in_LMS_Coach_Course__c) { |i| "Test - LC Section#{i}" }
    sequence(:Highlander_Accelerator_Course_ID__c)
    # Leaving out 'attributes' key b/c we don't currently use it.
    initialize_with { attributes.stringify_keys }
  end

end

# Example
#{
#    "done": true,
#    "records": [
#        {
#            "Default_Timezone__c": "America/Los_Angeles",
#            "Docusign_Template_ID__c": "FakeDocusignTemplateSJSU",
#            "Id": "a2Y17000000WLxqEAG",
#            "Highlander_LCPlaybook_Course_ID__c": "69",
#            "Name": "TEST: San Jose State University Fall 2020",
#            "Postaccelerator_Qualtrics_Survey_ID__c": "FakePostaccelSurveyIdSJSU",
#            "Preaccelerator_Qualtrics_Survey_ID__c": "FakePreaccelSurveyIdSJSU",
#            "School__c": "00117000015xF2cAAE",
#            "Section_Name_in_LMS_Coach_Course__c": "Test - LCs",
#            "Highlander_Accelerator_Course_ID__c": "71",
#            "attributes": {
#                "type": "Program__c",
#                "url": "/services/data/v48.0/sobjects/Program__c/a2Y17000000WLxqEAG"
#            }
#        }
#    ],
#    "totalSize": 1
#}
