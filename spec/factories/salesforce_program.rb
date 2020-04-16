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
    sequence(:LMS_Coach_Course_Id__c)
    sequence(:Name) { |i| "TEST: Program#{i}" }
    sequence(:Preaccelerator_Qualtrics_Survey_ID__c) { |i| "TestQualtricsSurvey#{i}" }
    sequence(:Postaccelerator_Qualtrics_Survey_ID__c) { |i| "TestQualtricsSurvey#{i}" }
    sequence(:School__c) { |i| "0011700001#{i}xF2cAAE" }
    sequence(:Section_Name_in_LMS_Coach_Course__c) { |i| "Test - LC Section#{i}" }
    sequence(:Target_Course_ID_in_LMS__c)
    # Leaving out 'attributes' key b/c we don't currently use it.
    initialize_with { attributes.stringify_keys }
  end

  # The SalesforceAPI converts the JSON returned from Salesforce into a "program_info"
  # hash that can be used to construct an app/models/program.rb object. This
  # represents that hash
  factory :salesforce_program_info, class: Hash do
    skip_create

    transient do
      program_info { build(:salesforce_program_record) }
    end
    
    name { program_info['Name'] }
    salesforce_id { program_info['Id'] }
    salesforce_school_id { program_info['SchoolId'] }
    fellow_course_id { program_info['Target_Course_ID_in_LMS__c'].to_i }
    leadership_coach_course_id { program_info['LMS_Coach_Course_Id__c'].to_i }
    leadership_coach_course_section_name { program_info['Section_Name_in_LMS_Coach_Course__c'] }
    timezone { program_info['Default_Timezone__c'].to_sym }
    docusign_template_id { program_info['Docusign_Template_ID__c'] }
    pre_accelerator_qualtrics_survey_id  { program_info['Preaccelerator_Qualtrics_Survey_ID__c'] }
    post_accelerator_qualtrics_survey_id { program_info['Postaccelerator_Qualtrics_Survey_ID__c'] }

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
#            "LMS_Coach_Course_Id__c": "69",
#            "Name": "TEST: San Jose State University Fall 2020",
#            "Postaccelerator_Qualtrics_Survey_ID__c": "FakePostaccelSurveyIdSJSU",
#            "Preaccelerator_Qualtrics_Survey_ID__c": "FakePreaccelSurveyIdSJSU",
#            "School__c": "00117000015xF2cAAE",
#            "Section_Name_in_LMS_Coach_Course__c": "Test - LCs",
#            "Target_Course_ID_in_LMS__c": "71",
#            "attributes": {
#                "type": "Program__c",
#                "url": "/services/data/v48.0/sobjects/Program__c/a2Y17000000WLxqEAG"
#            }
#        }
#    ],
#    "totalSize": 1
#}
