FactoryBot.define do

  # Represents a JSON object sent from Salesforce to the SalesforceController#update_contacts
  # endpoint. This object is created from this code: https://github.com/beyond-z/salesforce/blob/master/src/classes/BZ_SyncContactsToCanvas.apxc#L32

  factory :salesforce_update_contacts, class: Hash do
    skip_create # This isn't stored in the DB.
    sequence(:staff_email) { |i| "testsfcontactemail#{i}@sfexample.com" }
    contacts { [] }

    factory :salesforce_update_registered_contact, class: Hash do
      transient do
        fellow_user { build :fellow_user }
        new_email { nil }
      end
      contacts {
        [
          build(:salesforce_contact_in_portal,
            :Email => (new_email || fellow_user.email),
            :Id => fellow_user.salesforce_id,
            :FirstName => fellow_user.first_name,
            :LastName => fellow_user.last_name,
            :Canvas_Cloud_User_ID__c => fellow_user.canvas_user_id
          )
        ]
      }
    end

    initialize_with { attributes.stringify_keys }
  end

end

# Example
#{
#    "staff_email": "the_staff_email@bebraven.org",
#    "contacts": [
#        {
#            "AED_Tier_2__c": false,
#            "Accelerator_Portal_Account_Create_Link__c": "https://platform.bebraven.org/users/sign_up?u=0031555555555TOh",
#            "Accepts_Text__c": false,
#            "AccountId": "00111000024Q7qdAAC",
#            "AccountVIP__c": false,
#            "Account_Type__c": "Household",
#            "African_American__c": false,
#            "All_BZ_Regions__c": "Newark, NJ",
#            "Asian_American__c": false,
#            "Booster_Student__c": false,
#            "Booster_Volunteer__c": false,
#            "Braven_Programs_Role__c": "Fellow:Enrolled",
#            "Canvas_Cloud_User_ID__c": 4321.0,
#            "Canvas_Deactivated__c": false,
# NOTE: this is the old Portal ID, it's still in SF until we completely decommision the old Portal
#            "Canvas_User_ID__c": 1234.0,
#            "Contact_Funding_Relationship__c": "Prospect",
#            "Contact_Name__c": "_HL_ENCODED_/0031555555555TOh_HL_Brian xTestHighndrdevDevSandboxFellow2_HL__self_HL_",
#            "CreatedById": "005o0000000KOCmAAO",
#            "CreatedDate": "2021-04-01T19:36:45.000+0000",
#            "DLRS_Fellow_Most_Recent_Candidate__c": "a2Y11000001HfofEAC",
#            "Development_Connector__c": false,
#            "DoNotCall": false,
#            "ENG_TotalOut_CM__c": 0.0,
#            "Education_Affiliations__c": 0.0,
#            "Email": "brian+testhighndrdevdevsandboxfellow2_6@bebraven.org",
#            "Fellow__c": true,
#            "FirstName": "Brian",
#            "Full_Name__c": "_HL_ENCODED_https://bebraven--blueprint.lightning.force.com/0031555555555TOhAAM_HL_Brian xTestHighndrdevDevSandboxFellow2_HL__blank_HL_",
#            "Handle_With_Care__c": false,
#            "HasOptedOutOfEmail": false,
#            "HasOptedOutOfFax": false,
#            "Highlander_Portal_Account_Create_Link__c": "https://platform.braven.org/users/sign_up?u=003155555555TOh",
#            "Id": "00311555555555TOhAAM",
#            "Identify_As_First_Gen__c": false,
#            "Identify_As_Low_Income__c": false,
#            "Identify_As_Person_Of_Color__c": false,
#            "Import_from_Mailchimp_for_Stakeholder__c": false,
#            "Informal_Greeting__c": "Brian",
#            "Interested_in_opening_BZ__c": false,
#            "IsDeleted": false,
#            "IsEmailBounced": false,
#            "IsNewsletterSignupDisplay__c": "FALSE",
#            "IsNewsletterSignup__c": false,
#            "IsTestAccount__c": true,
#            "Is_In_Active_Recruitment_Campaign__c": false,
#            "Keep_Informed__c": false,
#            "LastModifiedById": "005o0000000KOCmAAO",
#            "LastModifiedDate": "2021-04-15T12:43:04.000+0000",
#            "LastName": "xTestHighndrdevDevSandboxFellow2",
#            "Last_CM_Email_Bounced__c": false,
#            "Latino__c": false,
#            "Leadership_Coach__c": false,
#            "Long_Salutation__c": "Brian xTestHighndrdevDevSandboxFellow2",
#            "Mailing_Preference__c": "No Preference",
#            "Mogli_SMS__Mogli_Opt_Out__c": false,
#            "Most_Recent_PAF_Survey_Status__c": "Not Started",
#            "Multi_Ethnic__c": false,
#            "Native_Alaskan__c": false,
#            "Native_American__c": false,
#            "Native_Hawaiian__c": false,
#            "Number_of_Booster_Student_Terms__c": 0.0,
#            "Number_of_Booster_Volunteer_Participants__c": 0.0,
#            "Number_of_Enrolled_Fellows__c": 1.0,
#            "Number_of_Enrolled_Leadership_Coaches__c": 0.0,
#            "Number_of_Fellow_Candidates__c": 1.0,
#            "Number_of_Fellows_Completed__c": 0.0,
#            "Number_of_Fellows__c": 0.0,
#            "Number_of_LC_Terms_Completed__c": 0.0,
#            "Number_of_Leadership_Coaches__c": 0.0,
#            "Number_of_Volunteer_Candidates__c": 0.0,
#            "OwnerId": "005o0000000KOCmAAO",
#            "PAF_Survey_Personalized_Link__c": "This Contact is not eligible to take the PAF survey",
#            "Pacific_Islander__c": false,
#            "Past_Present_or_Potential_Donor__c": false,
#            "Pell_Grant_Recipient__c": false,
#            "Portal_Account_Create_Link__c": "https://boosterplatform.braven.org/users/sign_up?u=003155555555TOh",
#            "Preferred_First_Name__c": "Brian",
#            "Publication_Name__c": "Brian xTestHighndrdevDevSandboxFellow2",
#            "SFSSDupeCatcher__Override_DupeCatcher__c": false,
#            "Short_Salutation__c": "Brian xTestHighndrdevDevSandboxFellow2",
#            "Stakeholders__c": false,
#            "Study_Abroad__c": false,
#            "SystemModstamp": "2021-04-15T12:43:04.000+0000",
#            "Trigger_for_Dupe_Match_Rule__c": false,
#            "VIP__c": false,
#            "View_Contact__c": "_HL_ENCODED_/00315555555TOh_HL_Brian xTestHighndrdevDevSandboxFellow2_HL__self_HL_",
#            "White__c": false,
#            "X18_Digit_Contact_ID__c": "00311555555555TOhAAM",
#            "attributes": {
#                "type": "Contact",
#                "url": "/services/data/v51.0/sobjects/Contact/003115555555TOhAAM"
#            },
#            "dupcheck__dc3DisableDuplicateCheck__c": false,
#            "npe01__HomeEmail__c": "brian+testhighndrdevdevsandboxfellow2_6@bebraven.org",
#            "npe01__Lifetime_Giving_History_Amount__c": 0.0,
#            "npe01__Organization_Type__c": "Household Account",
#            "npe01__PreferredPhone__c": "Home",
#            "npe01__Preferred_Email__c": "Personal",
#            "npe01__Private__c": false,
#            "npe01__SystemIsIndividual__c": false,
#            "npe01__Type_of_Account__c": "Individual",
#            "npo02__AverageAmount__c": 0.0,
#            "npo02__Formula_HouseholdMailingAddress__c": "\n ",
#            "npo02__LargestAmount__c": 0.0,
#            "npo02__LastMembershipAmount__c": 0.0,
#            "npo02__LastOppAmount__c": 0.0,
#            "npo02__NumberOfClosedOpps__c": 0.0,
#            "npo02__NumberOfMembershipOpps__c": 0.0,
#            "npo02__OppAmount2YearsAgo__c": 0.0,
#            "npo02__OppAmountLastNDays__c": 0.0,
#            "npo02__OppAmountLastYearHH__c": 0.0,
#            "npo02__OppAmountLastYear__c": 0.0,
#            "npo02__OppAmountThisYearHH__c": 0.0,
#            "npo02__OppAmountThisYear__c": 0.0,
#            "npo02__OppsClosed2YearsAgo__c": 0.0,
#            "npo02__OppsClosedLastNDays__c": 0.0,
#            "npo02__OppsClosedLastYear__c": 0.0,
#            "npo02__OppsClosedThisYear__c": 0.0,
#            "npo02__SmallestAmount__c": 0.0,
#            "npo02__TotalMembershipOppAmount__c": 0.0,
#            "npo02__TotalOppAmount__c": 0.0,
#            "npo02__Total_Household_Gifts__c": 0.0,
#            "npsp__CustomizableRollups_UseSkewMode__c": false,
#            "npsp__Deceased__c": false,
#            "npsp__Do_Not_Contact__c": false,
#            "npsp__Exclude_from_Household_Formal_Greeting__c": false,
#            "npsp__Exclude_from_Household_Informal_Greeting__c": false,
#            "npsp__Exclude_from_Household_Name__c": false,
#            "npsp__HHId__c": "00111000024Q7qdAAC",
#            "npsp__Primary_Contact__c": true,
#            "npsp__Soft_Credit_Last_N_Days__c": 0.0,
#            "npsp__is_Address_Override__c": false
#        }
#    ]
#}
